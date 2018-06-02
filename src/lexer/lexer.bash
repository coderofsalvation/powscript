#!/bin/bash

powscript_source lexer/stream.bash #<<EXPAND>>
powscript_source lexer/tokens.bash #<<EXPAND>>
powscript_source lexer/states.bash #<<EXPAND>>


# token:parse varname
# read a token from input and place it's id in the given variable
#
# e.g.
#
#  $ echo "abc" | {
#  >   stream:init
#  >   token:get -v value -c class
#  >   echo "v=$value c=$class"
#  > }
#  v=abc c=name

token:parse() { #<<NOSHADOW>>
  local token_id_var="$1"   # variables where the token id will be stored

  local linenumber_start    # tokens store starting and ending line and collumn
  local linenumber_end      # numbers for debugging purposes.
  local collumn_start       #
  local collumn_end         #

  local state               # describes the parsing context, e.g. if in double quotes or parentheses
  local class=undefined     # token type
  local token=""            # token value
  local c=''                # character being parsed

  local move=true           # if true, the stream will move to the next character after the parsing of the current one.
  local skip_term=true      # if true, the terminating character will not be part of the next token

  local belongs=true        # if false, the current character does not belong to the current token and the latter is finished
  local next_state=none     # if not none, the values of state and next_state are pushed to the stack, in that order
  local next_class=none     # if not none, after finishing the current token, the next one will be given this class
  local state_end=false     # if true, the current state will be not be pushed in the stack at the end of parsing.

  local glued=true          # true if the token is glued to the previous one

  stream:get-line-number linenumber_start
  stream:get-collumn     collumn_start

  # states are stored in a stack, to allow strings like 'a b$(echo c)d e'
  # to be handled by the lexer, where the tokens will be
  # 'a b', $(, echo, c, ), 'd e'.
  token:pop-state state

  # the token is done when its class is identified
  while [ $class = undefined ] && ! stream:end; do
    stream:get-character c

    case $state in
      quoted-escape)
        # if the escaped character is special, expand it before
        # putting it in the token, otherwise just put the character
        case "$c" in
          [bfnrtv]) printf -v token "%s\\$c" "$token" ;;
          *)        token+="$c" ;;
        esac
        state=double-quotes
        ;;

      unquoted-escape)
        # for escaped spaces and newlines
        case "$c" in
          $'\n') ;;
          *) token+="$c" ;;
        esac
        token:pop-state state
        ;;

      single-quotes)
        # accept all characters until an closing single quote is found
        if [ "$c" = "'" ]; then
          class=string
          state_end=true
        else
          token+="$c"
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
          "'")
            if [ -z "$token" ]; then
              token="'"
            else
              move=false
            fi
            class=string
            ;;
          *)
            token+="$c"
            ;;
        esac
        ;;

      whitespace)
        # indentation
        if [ "$c" = ' ' ]; then
          token+="$c"
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
          '[')
            token='$['
            move=true
            next_state=brackets
            ;;
          '{')
            token='${'
            move=true
            next_state=curly-braces
            ;;
          '#')
            token='$#'
            move=true
            ;;

          [0-9a-zA-Z_~])
            next_state=variable
            ;;

          @|\*)
            next_state=special-substitution
            ;;

          *)
            class=name
            ;;
        esac
        ;;

      special-substitution)
        token="$c"
        class=special
        state_end=true
        ;;

      variable)
        case "$c" in
          [0-9a-zA-Z_])
            token+="$c"
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

      equals)
        case "$c" in
          [~=])
            token="=$c"
            ;;
          *)
            move=false
            ;;
        esac
        state_end=true
        class=special
        ;;

      special)
        case "$c" in
          ':'|';'|','|'@'|'+'|'-'|'*'|'/'|'^'|'%'|'&')
            token+="$c"
            ;;
          *)
            move=false
            state_end=true
            class=special
            ;;
        esac
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
              token:error "unexpected $c on line %line. ${state/-/ }"
            else
              belongs=false
              state_end=true
              skip_term=false
              next_class=special
            fi
            ;;

          ':'|';'|','|'@'|'+'|'-'|'*'|'/'|'^'|'%'|'&')
            belongs=false
            skip_term=false
            [ -z "$token" ] && next_state=special
            ;;

          '=')
            if [[ "$token" =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ ]]; then
              belongs=false
              skip_term=false
              next_class=special
            elif [[ "$token" =~ ^[\&+*-\<\>\!/]$ ]]; then
              token+="$c"
              class=special
            elif [ -z "$token" ]; then
              belongs=false
              skip_term=false
              next_state='equals'
            else
              token+="$c"
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
            if stream:line-start; then
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
            token+="$c"
            ;;
        esac
        # this is still part of the '*)' state case
        if ! $belongs; then
          # found a terminating character while parsing
          if [ -z "$token" ]; then
            # if the current token is empty, don't return
            # any token, instead restart the loop.

            stream:get-line-number linenumber_start # update starting position
            stream:get-collumn     collumn_start    #

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
              token:push-state $state
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
    $move && stream:next-character
  done

  $state_end || token:push-state $state
  [ $next_state = none ] || token:push-state $next_state

  if stream:end; then
    if token:in-topmost-state; then
      if [ -n "$token" ] && [ "$class" = unidentified ]; then
        class=name
      else
        token=eof
        class=eof
        glued=false
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
        glued=false
      else
        token:unfinished-input-error "$state" "$linenumber_start" "$collumn_start"
      fi
    fi
  fi

  stream:get-collumn     collumn_end
  stream:get-line-number linenumber_end

  token:store\
    "$token" "$class" "$glued"\
    "$linenumber_start" "$linenumber_end"\
    "$collumn_start" "$collumn_end"\
    "$token_id_var"
}
noshadow token:parse

token:get-id() {
  if token:in-topmost; then
    token:parse "$1"
  else
    token:get-selected "$1"
    token:forward
  fi
}

token:peek-id() {
  if token:in-topmost; then
    token:parse "$1"
    token:backtrack
  else
    token:get-selected "$1"
  fi
}

token:skip() {
  local _
  if token:in-topmost; then
    token:parse _
  else
    token:forward
  fi
}


token:get() {
  local __get_token__token
  token:get-id __get_token__token
  token:all-from "$@" $__get_token__token
}


token:peek() {
  local __peek_token__token
  token:peek-id __peek_token__token
  token:all-from "$@" $__peek_token__token
}


token:next-is() {
  local value class res=false
  token:peek -v value -c class
  case $# in
    1)
      [ "$class" = "$1" ] && res=true
      ;;
    2)
      [[ "$class" = "$1" ]] && [[ "$value" = "$2" ]] && res=true
      ;;
  esac
  $res
}


token:ignore-whitespace() {
  if token:next-is whitespace; then
    token:skip
  fi
}


token:backtrack() {
  token:move-back-index
}

token:get-specific() { #<<NOSHADOW>>
  local value class required="$1" out="$2"
  token:get -v value -c class
  if [ ! $class = $required ]; then
    token:error "Wrong token: found a $class of value $value when a $required was required"
  else
    setvar "$out" "$value"
  fi
}
noshadow token:get-specific 1

token:require() {
  local req_class="$1" req_value="$2"
  local value class

  token:get -v value -c class
  if [ ! "$req_class $req_value" = "$class $value" ]; then
    token:error "Wrong token: found a $class of value $value when a $req_class of value $req_value was required"
  fi
}


token:unfinished-input-error() {
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
    token:find-by value "$opener" token
    if [ ! $token = -1 ]; then
      token:from $token linenumber_start line
      token:from $token collumn_start collumn
      token:error "unclosed ${state/-/ }, last open one found in line $line, collumn $collumn"
    else
      token:error "unclosed ${state/-/ }"
    fi
  else
    if [[ "$state" =~ quotes ]]; then
      line="$2"
      collumn="$3"
      token:error "unfinished ${state/-/ }, starting in line $line, collumn $collumn"
    else
      token:error "unexpected eof"
    fi
  fi
}

token:error() {
  local message="error: ${1//%line/$(stream:get-line-number)}"
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

token:to-json() {
  local token
  stream:init

  echo '{'
  while ! stream:end; do
    token:get -v value -c class -g glued
    echo "    'value': '$value'"
    echo "    'class': '$class'"
    echo "    'glued': $glued"
    echo '  }'
  done
  echo '}'
}
