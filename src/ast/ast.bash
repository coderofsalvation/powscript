powscript_source ast/ast_heap.bash


# try_parse_ast
#
# try parsing an ast expression from the input,
# printing 'top' on success or the last
# parser state on failure.

try_parse_ast() {
  (
    local ast
    POWSCRIPT_INCOMPLETE_STATE=

    trap '
      if [ -n "$POWSCRIPT_INCOMPLETE_STATE" ]; then
        echo "$POWSCRIPT_INCOMPLETE_STATE"
      else
        ast_last_state
      fi
      exit' EXIT

    POWSCRIPT_ALLOW_INCOMPLETE=true parse_ast ast
    exit
  )
}

# parse_ast $out
#
# parse an ast expression form the input,
# storing it in $out.

parse_ast() {
  parse_ast_linestart "$1"
}

ast_error() {
  local message="$1"

  if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
    POWSCRIPT_INCOMPLETE_STATE="error: $message"
  else
    >&2 echo "$message"
  fi
  exit
}

# parse_ast_linestart $out
#
# test that there is no indentation before proceeding
# to parse the expression.

parse_ast_linestart() {
  local value class linenumber_start

  get_token_and_set value class linenumber_start

  if [ "$class" = whitespace ]; then
    ast_error "indentation error at line $linenumber_start, unexpected indentation of $value."
  else
    backtrack_token
    parse_ast_top "$1"
  fi
}
noshadow parse_ast_linestart


# parse_ast_top $out
#
# analyze first expression and dispatch to the
# appropriate function based on it.

parse_ast_top() {
  local out="$1"
  local expr expr_head

  parse_ast_expr expr
  from_ast $expr head expr_head

  case $expr_head in
    name)
      local expr_value
      from_ast $expr value expr_value
      case "$expr_value" in
        'if')      parse_ast_if      $expr ;;
        'while')   parse_ast_while   $expr ;;
        'switch')  parse_ast_switch  $expr ;;
        'require') parse_ast_require $expr ;;
        *)
          parse_ast_post_top_name $expr "$out";;
      esac
      ;;
    *)
      parse_ast_commandcall $expr "$out"
      ;;
  esac
}
noshadow parse_ast_top


# parse_ast_expr $out
#
# basic expression, which can be a name,
# string, substitution or concatenation.

parse_ast_expr() {
  local out="$1"
  local value class glued=true
  local state=first
  local expression child

  new_ast expression

  while [ ! $state = finished ]; do
    get_token_and_set value class glued

    if $glued || [ $state = first ]; then
      case $state in
        first)
          child=$expression
          state=second
          ;;
        second)
          case "$class: $value" in
            'special: '[='('')'])
              ;;
            *)
              new_ast expression
              ast_set $expression head cat
              ast_push_child $expression $child
              new_ast child
              state=cat
              ;;
          esac
          ;;
        cat)
          new_ast child
          ;;
      esac

      case $class in
        name|string)
          ast_set $child head  $class
          ast_set $child value "$value"
          ;;
        special)
          case "$value" in
            '$')
              ast_set_to_overwrite $child
              parse_ast_substitution child
              ;;
            *)
              backtrack_token
              state=finished
              ;;
          esac
          ;;
        newline|eof)
          if [ $state = second ]; then
            ast_set $expression head newline
          else
            backtrack_token
          fi
          state=finished
          ;;
      esac
      [ $state = cat ] && ast_push_child $expression $child
    else
      backtrack_token
      state=finished
    fi
  done
  setvar "$out" $expression
}
noshadow parse_ast_expr


# parse_ast_post_top_name $name $ast
#
# parse top ast that starts with a non-special name
# or a string

parse_ast_post_top_name() {
  local name_ast="$1" out="$2"
  local value class glued

  get_token_and_set value class glued

  if [ $class = special ]; then
    case "$value" in
      '=')
        local expr assigned_value

        new_ast expr
        ast_set $expr head assign
        ast_push_child $expr $name_ast

        parse_ast_arguments $expr

        setvar "$out" $expr
        ;;
      '(')
        backtrack_token
        parse_ast_function_definition $name_ast "$out"
        ;;
    esac
  else
    backtrack_token
    parse_ast_commandcall $name_ast "$out"
  fi
}
noshadow parse_ast_post_top_name 1


# parse_ast_commandcall $command $out
#
# parse a command call, consisting of
# a command and a series of space
# separated arguments

parse_ast_commandcall() {
  local command_ast=$1 out="$2"
  local expression child expr_head=none

  new_ast expression
  ast_set $expression head 'call'
  ast_push_child $expression $command_ast

  parse_ast_arguments $expression

  setvar "$out" $expression
}
noshadow parse_ast_commandcall 1

parse_ast_arguments() {
  local expr="$1"
  local expr_head=none child

  while [ ! $expr_head = newline ]; do
    parse_ast_expr child
    from_ast $child head expr_head

    if [ ! $expr_head = newline ]; then
      ast_push_child $expr $child
    fi
  done
}


parse_ast_function_definition() {
  local name=$1 out="$2"
  local expr args nl block
  local nl_head

  new_ast expr
  ast_set $expr head function-def

  parse_ast_list  args
  parse_ast_expr  nl

  from_ast $nl head nl_head
  [ $nl_head = newline ] || ast_error "trailing expression after function definition: $(ast_print $nl)"

  parse_ast_block fn block


  ast_push_child $expr $name
  ast_push_child $expr $args
  ast_push_child $expr $block

  setvar "$out" $expr
}
noshadow parse_ast_function_definition 1


parse_ast_block() {
  local state=$1 out="$2"
  local expr child indent_state indent_layers
  local value class linenumber_start

  new_ast expr
  ast_set $expr head block

  ast_push_state $state
  ast_new_indentation

  ast_indentation_layers indent_layers
  ast_set $expr value $indent_layers

  indent_state=ok

  while [ $indent_state = ok ]; do
    get_token_and_set value class linenumber_start

    if [ $class = eof ] && ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
      POWSCRIPT_INCOMPLETE_STATE="$(ast_last_state)"
      exit
    fi

    ast_test_indentation "$value" $class indent_state

    case $indent_state in
      ok)
        parse_ast_top child
        ast_push_child $expr $child
        ;;
      error*)
        local req found or_more=""
        [ $indent_state = error-start ] && or_more=" or more"

        ast_indentation_required req
        ast_count_indentation "$value" $class found
        ast_error "indentation error at line $linenumber_start, expected $req spaces$or_more, found $found."
        ;;
    esac
  done

  ast_pop_state
  setvar "$out" $expr
}
noshadow parse_ast_block 1



parse_ast_list() {
  local out="$1"
  local expr child open=true
  local t class value

  new_ast expr
  ast_set $expr head list

  get_token t
  while $open; do
    get_token_and_set value class

    if [ "$class: $value" = "special: )" ]; then
      open=false
    else
      backtrack_token
      parse_ast_expr child

      ast_push_child $expr $child
    fi
  done

  setvar "$out" $expr
}
noshadow parse_ast_list

