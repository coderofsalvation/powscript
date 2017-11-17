#!/bin/bash

powscript_source lexer/stream.bash #<<EXPAND>>
powscript_source lexer/tokens.bash #<<EXPAND>>
powscript_source lexer/states.bash #<<EXPAND>>


# parse_token varname
# read a token from input and place it's id in the given variable
#
# e.g.
#
#  $ echo "abc" | {
#  > init_stream
#  > get_token token
#  > from_token $token value
#  > from_token $token class
#  > }
#  abc
#  name

parse_token() { #<<NOSHADOW>>
  local token_id_var="$1"   # variables where the token id will be stored

  local linenumber_start    # tokens store starting and ending line and collumn
  local linenumber_end      # numbers for debugging purposes.
  local collumn_start
  local collumn_end

  local state               # describes the parsing context, e.g. if in double quotes or parentheses
  local class=undefined     # token type
  local token=""            # token value
  local c=''                # character being parsed

  local move=true           # if true, the stream will move to the next character after the parsing of the current one.
  local skip_term=true      # if true, the terminating character will not be part of the next token

  local belongs=true        # if false, the current character does not belong to the current token and the latter is finished
  local next_state=none     # if not none, the current state and next state are pushed to the stack, in that order
  local next_class=none     # if not none, after finishing the current token, the next one will be given this class
  local state_end=false     # if true, the current state will be not be pushed in the stack at the end of parsing.

  local glued=true          # true if the token is glued to the previous one

  get_line_number linenumber_start
  get_collumn collumn_start

  # states are stored in a stack, to allow strings like 'a b$(echo c)d e'
  # to be handled by the lexer, where the tokens will be
  # 'a b', $(, echo, c, ), 'd e'.
  pop_state state

  # the token is done when its class is identified
  while [ $class = undefined ] && ! end_of_file; do
    get_character c

    case $state in
      quoted-escape)
        # if the escaped character is special, expand it before
        # putting it in the token, otherwise just put the character
        case "$c" in
          [bfnrtv]) printf -v token "%s\\$c" "$token" ;;
          *)        token="$token$c" ;;
        esac
        state=double-quotes
        ;;

      unquoted-escape)
        # for escaped spaces and newlines
        case "$c" in
          $'\n') ;;
          *) token="$token$c" ;;
        esac
        pop_state state
        ;;

      single-quotes)
        # accept all characters until an closing single quote is found
        if [ "$c" = "'" ]; then
          class=string
          state_end=true
        else
          token="$token$c"
        fi
        ;;

      double-quotes)
        # characters can be escaped, and expressions substituted in.
        # on substitutions, break the string and restart it after the
        # substitution is finished
        case "$c" in
          '\')
            state=quoted-escape
            ;;
          '$')
            class=string
            next_state=substitution
            ;;
          '"')
            class=string
            state_end=true
            ;;
          *)
            token="$token$c"
            ;;
        esac
        ;;

      whitespace)
        # indentation
        if [ "$c" = ' ' ]; then
          token="$token$c"
        else
          token=${#token}
          move=false
          class=whitespace
          state_end=true
        fi
        ;;

      substitution)
        token='$'
        class=special
        state_end=true
        move=false
        case "$c" in
          '(')
            token='$('
            move=true
            next_state=parentheses
            ;;
          '{')
            token='${'
            move=true
            next_state=curly-braces
            ;;

          [0-9a-zA-Z_]) next_state=variable ;;
          *)            class=name ;;
        esac
        ;;

      variable)
        case "$c" in
          [0-9a-zA-Z_])
            token="$token$c"
            ;;
          *)
            class=name
            state_end=true
            move=false
            ;;
        esac
        ;;

      comment)
        # ignore all until newline
        if [ "$c" = $'\n' ]; then
          token="$c"
          class=newline
          state_end=true
        fi
        ;;

      *)
        # all other contexts follow similar parsing rules,
        # the only difference being what token ends it
        case "$c" in
          "'"|'"'|'('|'['|'{')
            case "$c" in
              "'") next_state=single-quotes ;;
              '"') next_state=double-quotes ;;
              '(') next_state=parentheses;  skip_term=false; next_class=special ;;
              '[') next_state=brackets;     skip_term=false; next_class=special ;;
              '{') next_state=curly-braces; skip_term=false; next_class=special ;;
            esac
            belongs=false
            ;;

          ')'|']'|'}')
            if { { [ "$state" = parentheses  ] && [ ! "$c" = ')' ]; } ||
                 { [ "$state" = brackets     ] && [ ! "$c" = ']' ]; } ||
                 { [ "$state" = curly-braces ] && [ ! "$c" = '}' ]; } ;}; then
              parse_error "unexpected $c on line %line. ${state/-/ }"
            else
              belongs=false
              state_end=true
              skip_term=false
              next_class=special
            fi
            ;;

          ':'|';'|',')
            belongs=false
            skip_term=false
            next_class=special
            ;;

          '=')
            if [[ "$token" =~ [a-zA-Z_][a-zA-Z_0-9]* ]]; then
              belongs=false
              skip_term=false
              next_class=special
            else
              token="$token$c"
            fi
            ;;
          '\')
            state='unquoted-escape'
            ;;


          '$')
            belongs=false
            next_state=substitution
            skip_term=false
            ;;

          $'\n')
            [ -z "$token" ] && glued=false
            belongs=false
            next_class=newline
            ;;

          ' ')
            if line_start; then
              belongs=false
              skip_term=false
              next_state=whitespace
            elif [ -n "$token" ]; then
              belongs=false
            else
              glued=false
            fi
            ;;

          '#')
            belongs=false
            next_state=comment
            ;;

          *)
            token="$token$c"
            ;;
        esac
        if ! $belongs; then
          # found a terminating character while parsing
          if [ -z "$token" ]; then
            # if the current token is empty, don't return
            # any token, instead restart the loop.

            get_line_number linenumber_start # update starting position
            get_collumn collumn_start        #

            # we skip the terminating character by not
            # adding it to the current empty token
            if $skip_term; then
              token=""
            else
              token="$c"
              skip_term=true
            fi

            # having a next_class means the terminating character
            # forms a token on their own, e.g. '('. It will be
            # a single character token.
            if [ ! $next_class = none ]; then
              class=$next_class
            fi

            if [ ! $next_state = none ]; then
              push_state $state
              state=$next_state
              next_state=none
            fi
          else
            # if the token has any characters, return the token
            # and forget the terminating character.
            class=name
            state_end=false
            next_state=none

            move=false # ensures the terminating character is read again next call
          fi
        fi
        ;;
    esac
    $move && next_character
  done

  $state_end || push_state $state
  [ $next_state = none ] || push_state $next_state

  if end_of_file; then
    if in_topmost_state; then
      if [ -n "$token" ] && [ "$class" = unidentified ]; then
        class=name
      else
        token=eof
        class=eof
      fi
    else
      if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
        case "$state" in
          parentheses)  state='('; ;;
          brackets)     state='['; ;;
          curly-braces) state='{'; ;;
        esac
        POWSCRIPT_INCOMPLETE_STATE="$state"
        token=eof
        class=eof
      else
        unfinished_input_error "$state" "$linenumber_start" "$collumn_start"
      fi
    fi
  fi

  get_collumn collumn_end
  get_line_number linenumber_end

  store_token\
    "$token" "$class" "$glued"\
    "$linenumber_start" "$linenumber_end"\
    "$collumn_start" "$collumn_end"\
    "$token_id_var"
}
noshadow parse_token

get_token_id() {
  if in_topmost_token; then
    parse_token "$1"
  else
    get_selected_token "$1"
    forward_token
  fi
}

peek_token_id() {
  if in_topmost_token; then
    parse_token "$1"
    backtrack_token
  else
    get_selected_token "$1"
  fi
}

skip_token() {
  local _
  if in_topmost_token; then
    parse_token _
  else
    forward_token
  fi
}


get_token() {
  local __get_token__token
  get_token_id __get_token__token
  all_from_token "$@" $__get_token__token
}


peek_token() {
  local __peek_token__token
  peek_token_id __peek_token__token
  all_from_token "$@" $__peek_token__token
}


next_token_is() {
  local value class
  peek_token -v value -c class
  case $# in
    1)
      [ "$class" = "$1" ]
      ;;
    2)
      [[ "$class" = "$1" ]] && [[ "$value" = "$2" ]]
      ;;
  esac
}


token_ignore_whitespace() {
  if next_token_is whitespace; then
    skip_token
  fi
}


backtrack_token() {
  move_back_token_index
}

get_specific_token() { #<<NOSHADOW>>
  local value class required="$1" out="$2"
  get_token -v value -c class
  if [ ! $class = $required ]; then
    parse_error "Wrong token: found a $class of value $value when a $required was required"
  else
    setvar "$out" "$value"
  fi
}
noshadow get_specific_token 1

require_token() {
  local req_class="$1" req_value="$2"
  local value class

  get_token -v value -c class
  if [ ! "$req_class $req_value" = "$class $value" ]; then
    parse_error "Wrong token: found a $class of value $value when a $req_class of value $req_value was required"
  fi
}


unfinished_input_error() {
  local token
  local opener=
  local state="$1"
  local line
  local collumn
  case "$state" in
    parentheses)    opener='\$?\('  ;;
    brackets)       opener='\['     ;;
    curly-braces)   opener='\$?\{'  ;;
  esac
  if [ -n "$opener" ]; then
    find_token_by value "$opener" token
    if [ ! $token = -1 ]; then
      from_token $token linenumber_start line
      from_token $token collumn_start collumn
      parse_error "unclosed ${state/-/ }, last open one found in line $line, collumn $collumn"
    else
      parse_error "unclosed ${state/-/ }"
    fi
  else
    if [[ "$state" =~ quotes ]]; then
      line="$2"
      collumn="$3"
      parse_error "unfinished ${state/-/ }, starting in line $line, collumn $collumn"
    else
      parse_error "unexpected eof"
    fi
  fi
}

parse_error() {
  local message="error: ${1//%line/$(get_line_number)}"
  if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
    if ${POWSCRIPT_SHOW_INCOMPLETE_MESSAGE-false}; then
      >&2 echo "$message"
    fi
    POWSCRIPT_INCOMPLETE_STATE="$message"
    exit
  else
    >&2 echo "$message"
    exit 1
  fi
}

tokens_to_json() {
  local token
  init_stream

  echo '{'
  while ! end_of_file; do
    get_token -v value -c class -g glued
    from_token $token value value
    from_token $token class class
    from_token $token glued glued
    echo "  ${token}: {"
    echo "    'value': '$value'"
    echo "    'class': '$class'"
    echo "    'glued': $glued"
    echo '  }'
  done
  echo '}'
}