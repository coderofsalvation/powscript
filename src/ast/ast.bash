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
        'if')      parse_ast_if 'if' "$out" ;;
        'while')   parse_ast_while   "$out" ;;
        'switch')  parse_ast_switch  "$out" ;;
        'require') parse_ast_require "$out" ;;
        *)
          parse_ast_post_top_name $expr "$out";;
      esac
      ;;
    newline)
      setvar "$out" -1
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
            'special: =')
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
            '${')
              ast_set_to_overwrite $child
              parse_ast_curly_substitution child
              ;;
            '$(')
              ast_set_to_overwrite $child
              parse_ast_command_substitution child
              ;;
            ')')
              local ast_state
              ast_last_state ast_state
              if [ $state = cat ]; then
                backtrack_token
                state=finished
              elif [ "$ast_state" = '$(' ]; then
                ast_set $child head command-substitution-end
              else
                ast_error "unmatched ) found."
              fi
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

parse_ast_substitution() {
  local subst out="$1"
  local value class

  get_token_and_set value class

  case "$class" in
     special)
       ast_error "unimplemented"
       ;;
    name)
      make_ast subst simple-substitution "$value"
      ;;
  esac
  setvar "$out" $subst
}
noshadow parse_ast_substitution

parse_ast_curly_substitution() {
  local out="$1"
  local subst value class name

  get_token_and_set value class
  if [ ! "$class" = name ]; then
    ast_error "unexpected $class token '$value' in variable substitution"
  fi
  name="$value"

  get_token_and_set value class
  if [ ! "$class" = special ]; then
    ast_error "unexpected $class token '$value' in variable substitution"
  fi
  case "$value" in
    '}')
      make_ast subst simple-substitution "$name"
      ;;
    *)
      ast_error "unimplemented"
      ;;
  esac

  setvar "$out" $subst
}
noshadow parse_ast_curly_substitution

parse_ast_command_substitution() {
  local out="$1"
  local command call

  make_ast "$out" command-substitution ''

  ast_push_state '$('
  parse_ast_expr command
  parse_ast_commandcall $command call
  ast_pop_state

  ast_push_child "${!out}" $call
}
noshadow parse_ast_command_substitution


# parse_ast_post_top_name $name $ast
#
# parse top ast that starts with a non-special name
# or a string

parse_ast_post_top_name() {
  local name_ast="$1" out="$2"
  local value class glued

  get_token_and_set value class glued

  case "$class: $value" in
    'special: =')
      local assign

      new_ast assign
      ast_set $assign head assign
      ast_push_child $assign $name_ast

      parse_ast_arguments $assign

      setvar "$out" $assign
      ;;
    'special: (')
      backtrack_token
      parse_ast_function_definition $name_ast "$out"
      ;;
    *)
      backtrack_token
      parse_ast_commandcall $name_ast "$out"
      ;;
  esac
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

  make_ast expression call $command_ast

  parse_ast_arguments $expression

  setvar "$out" $expression
}
noshadow parse_ast_commandcall 1

parse_ast_arguments() {
  local expr="$1"
  local expr_head=none child unfinished=true

  while $unfinished; do
    parse_ast_expr child
    from_ast $child head expr_head

    case $expr_head in
      newline|command-substitution-end)
        unfinished=false
        ;;
      *)
        ast_push_child $expr $child
        ;;
    esac
  done
}


# parse_ast_if $block_type $out
#
# parses a if statement, which is
# a conditional expression, followed
# by a newline, block, and possibly an
# else or elif statements

parse_ast_if() {
  local block_type=$1 out="$2"
  local expr conditional block

  new_ast expr
  ast_set $expr head 'if'

  parse_ast_conditional conditional
  parse_ast_require_newline "condition in if statement"
  parse_ast_block $block_type block

  ast_push_child $expr $conditional
  ast_push_child $expr $block

  parse_ast_post_if $expr

  setvar "$out" $expr
}
noshadow parse_ast_if 1

parse_ast_post_if() {
  local if_ast="$1"
  local value class clause_type

  get_token_and_set value class

  if [ $class = name ]; then
    clause_type="$value"
  else
    clause_type=none
  fi

  case "$clause_type" in
    else)
      local else_ast else_block
      new_ast else_ast
      ast_set $else_ast head else

      parse_ast_require_newline "else statement"
      parse_ast_block el else_block

      ast_push_child $else_ast $else_block
      ast_push_child $if_ast $else_ast
      ;;
    elif)
      local elif_ast
      parse_ast_if elif_ast ef

      ast_push_child $if_ast $elif_ast
      ;;
    *)
      local end_ast
      new_ast end_ast
      ast_set $end_ast head end_if

      ast_push_child $if_ast $end_ast
      ;;
  esac
}

parse_ast_conditional() {
  local out="$1"
  local condition
  local initial initial_head initial_value

  new_ast condition
  ast_set $condition head condition

  parse_ast_expr initial

  from_ast $initial head  initial_head
  from_ast $initial value initial_value

  if [ "$initial_head: $initial_head" = "name: not" ]; then
    local not_expr
    parse_ast_conditional not_expr

    ast_set $condition value "not"
    ast_push_child $condition $not_expr
  else

    local value class is_command=false
    get_token_and_set value class

    if [ ! $class = name ]; then
      backtrack_token
      is_command=true
    else
      case "$value" in
        is|isnt|'>'|'<'|'<='|'>='|'!='|and|or|match)
          ast_set $condition value "$value"
          ;;
        *)
          backtrack_token
          is_command=true
          ;;
      esac
    fi

    if $is_command; then
      local command

      ast_set $condition value "$command"
      parse_ast_commandcall $initial command

      ast_push_child $condition $command
      backtrack_token
    else
      local left right
      left=$initial
      parse_ast_expr right

      ast_push_child $condition $left
      ast_push_child $condition $right
    fi
  fi
  setvar "$out" $condition
}
noshadow parse_ast_conditional



parse_ast_function_definition() {
  local name=$1 out="$2"
  local expr args block

  new_ast expr
  ast_set $expr head function-def

  parse_ast_list args
  parse_ast_require_newline "function definition"
  parse_ast_block fn block

  ast_push_child $expr $name
  ast_push_child $expr $args
  ast_push_child $expr $block

  setvar "$out" $expr
}
noshadow parse_ast_function_definition 1

parse_ast_require_newline() {
  local nl nl_head
  parse_ast_expr nl
  from_ast $nl head nl_head
  [ $nl_head = newline ] || ast_error "trailing expression after ${1}: $(ast_print $nl)"
}

parse_ast_block() {
  local state=$1 out="$2"
  local expr child indent_state indent_layers
  local value class linenumber_start ln="0"

  new_ast expr
  ast_set $expr head block

  ast_push_state $state
  ast_new_indentation

  ast_indentation_layers indent_layers
  ast_set $expr value $indent_layers

  indent_state=ok

  while [ ! $indent_state = end ]; do
    get_token_and_set value class linenumber_start

    ast_test_indentation "$value" $class indent_state

    case $indent_state in
      ok)
        parse_ast_top child
        if [ ! "$child" = -1 ]; then
          ast_push_child $expr $child
          ln="$linenumber_start"
        fi
        ;;
      error*)
        if [ $class = eof ] && ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          if [ ! "$indent_state" = error-eof ] || [ "$ln" = "$linenumber_start" ]; then
            POWSCRIPT_INCOMPLETE_STATE="$(ast_last_state)"
          else
            POWSCRIPT_INCOMPLETE_STATE="top"
          fi
          exit
        fi

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
  backtrack_token
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

