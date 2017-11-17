powscript_source ast/ast_heap.bash #<<EXPAND>>


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
    if ${POWSCRIPT_SHOW_INCOMPLETE_MESSAGE-false}; then
      >&2 echo "$message"
    fi
  else
    >&2 echo "$message"
  fi
  exit
}

# parse_ast_linestart $out
#
# test that there is no indentation before proceeding
# to parse the expression.

parse_ast_linestart() { #<<NOSHADOW>>
  local value class line

  get_token -v value -c class -ls line

  if [ "$class" = whitespace ]; then
    ast_error "indentation error at line $line, unexpected indentation of $value."
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

parse_ast_top() { #<<NOSHADOW>>
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
        'for')     parse_ast_for     "$out" ;;
        'while')   parse_ast_while   "$out" ;;
        'switch')  parse_ast_switch  "$out" ;;
        'require') parse_ast_require "$out" ;;
        *)
          if next_token_is special '('; then
            parse_ast_function_definition $expr "$out"
          else
            parse_ast_commandcall $expr "$out"
          fi
          ;;
      esac
      ;;
    assign|indexing-assign)
      setvar "$out" $expr
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

parse_ast_expr() { #<<NOSHADOW>>
  local out="$1"
  local value class glued
  local root root_head=undefined
  local expression exprnum=0 last_expression

  new_ast root

  while [ $root_head = undefined ]; do
    token_ignore_whitespace
    get_token -v value -c class -g glued

    if $glued || [ $exprnum = 0 ]; then
      case $class in
        name|string)
          make_ast expression $class "$value"
          ;;
        special)
          case "$value" in
            '$')
              parse_ast_substitution expression
              ;;

            '${')
              parse_ast_curly_substitution expression
              ;;

            '$(')
              parse_ast_command_substitution expression
              ;;

            '(')
              if [ $exprnum -gt 0 ]; then
                root_head=determinable
              else
                ast_push_state '('
                parse_ast_list root
                root_head=list
                ast_pop_state
              fi
              ;;

            ')'|']'|'}')
              local opener
              case $value in
                ')') opener='('; ;;
                ']') opener='['; ;;
                '}') opener='{'; ;;
              esac
              if ast_state_is $opener; then
                root_head=determinable
              else
                make_ast expression string "$value"
              fi
              ;;

            '=')
              if [ $exprnum = 1 ] && ast_is $last_expression name; then
                parse_ast_expr expression
                ast_push_child $root $expression
                root_head=assign
              else
                make_ast expression string "="
              fi
              ;;
            '[')
              if [ $exprnum = 1 ] && ast_is $last_expression name; then
                local index
                ast_push_state '['
                parse_ast_expr index

                require_token special ']'
                ast_pop_state

                if next_token_is special '=' && ast_is $index name; then
                  skip_token
                  parse_ast_expr expression
                  root_head=indexing-assign
                  ast_push_child $root $index
                  ast_push_child $root $expression
                else
                  local left_bracket right_bracket
                  make_ast left_bracket  name '['
                  make_ast right_bracket name ']'

                  ast_push_child $root $left_bracket
                  ast_push_child $root $index

                  expression=$right_bracket
                  exprnum=3
                fi
              else
                make_ast expression string "["
              fi
              ;;

            *)
              make_ast expression name "$value"
              ;;
          esac
          ;;
        newline|eof)
          root_head=$class
          ;;
        *)
          ast_error "token of class $class found when parsing an expression ast"
          ;;
      esac

      if [ $root_head = undefined ]; then
        ast_push_child $root $expression
        exprnum=$((exprnum+1))
        last_expression=$expression
      fi
    else
      root_head=determinable
    fi

    if [ $root_head = determinable ]; then
      if [ $exprnum = 1 ]; then
        ast_clear $root
        root=$last_expression
        from_ast $root head root_head
      else
        root_head=cat
      fi
      backtrack_token
    fi
  done
  ast_set $root head $root_head
  #>&2 echo "$(ast_print $root) :: $(from_ast $root head)"

  setvar "$out" $root
}
noshadow parse_ast_expr

parse_ast_expr_and_set() {
  local __paeas_expr
  parse_ast_expr __paeas_expr

  while [ $# -gt 0 ]; do
    case "$1" in
      -e|--expr)
        setvar "$2" $__paeas_expr
        shift 2
        ;;
      -v|--value)
        from_ast $__paeas_expr value "$2"
        shift 2
        ;;
      -h|--head)
        from_ast $__paeas_expr head "$2"
        shift 2
        ;;
      -c|--children)
        from_ast $__paeas_expr children "$2"
        shift 2
        ;;
      -@|--@children)
        ast_children $__paeas_expr "${@:2}"
        shift $#
        ;;
      *)
        ast_error "Invalid flag $1, expected -[evhc@]"
        ;;
    esac
  done
}

parse_ast_specific_expr() { #<<NOSHADOW>>
  local expr expr_head required="$1" out="$2"
  parse_ast_expr expr
  from_ast $expr head expr_head

  if [ $expr_head = $required ]; then
    setvar "$out" $expr
  else
   ast_error "Wrong expression: Found a $expr_head when a $required was required"
 fi
}
noshadow parse_ast_specific_expr 1

parse_ast_substitution() { #<<NOSHADOW>>
  local subst out="$1"
  local expr value head varname index lb rb aft
  local cat_children cat_array

  parse_ast_expr_and_set -e expr -v value -h head -@ varname lb index rb aft

  case "$head" in
    name)
      make_ast subst simple-substitution "$value"
      ;;
    cat)
       if ast_is $lb name '['; then
         from_ast $varname value value
         make_ast subst indexing-substitution "$value" $index
         if [ -n "$aft" ]; then
           from_ast $expr children cat_children
           cat_array=( $cat_children )
           make_ast subst cat $subst "${cat_array[@:4]}"
         fi
       else
         subst=$expr
       fi
      ;;
    *)
      ast_error "unimplemented"
      ;;
  esac
  setvar "$out" $subst
}
noshadow parse_ast_substitution

parse_ast_curly_substitution() { #<<NOSHADOW>>
  local out="$1"
  local subst head

  ast_push_state '{'
  parse_ast_expr_and_set -e subst -h head

  case "$head" in
    *substitution)
      require_token special '}'
      ast_pop_state
      ;;
    *)
      ast_error "unimplemented"
      ;;
  esac

  setvar "$out" $subst
}
noshadow parse_ast_curly_substitution

parse_ast_command_substitution() { #<<NOSHADOW>>
  local out="$1"
  local cmd call

  make_ast "$out" command-substitution ''

  ast_push_state '$('
  parse_ast_expr cmd
  parse_ast_commandcall $cmd call
  ast_pop_state

  ast_push_child "${!out}" $call
}
noshadow parse_ast_command_substitution


# parse_ast_commandcall $command $out
#
# parse a command call, consisting of
# a command and a series of space
# separated arguments

parse_ast_commandcall() { #<<NOSHADOW>>
  local command_ast=$1 out="$2"
  local expression child expr_head=none

  make_ast expression call '' $command_ast

  parse_ast_arguments $expression

  setvar "$out" $expression
}
noshadow parse_ast_commandcall 1

parse_ast_arguments() {
  local expr="$1"
  local expr_head=none expr_value child unfinished=true state state_s

  ast_last_state state
  case $state in
    '$(')
      state_s='c'
      ;;
    top)
      state_s='t'
      ;;
    '==')
      state_s='i'
      ;;
    *)
      state_s='o'
      ;;
  esac


  while $unfinished; do
    parse_ast_expr child
    from_ast $child head expr_head

    case "$state_s/$expr_head" in
      'c/command-substitution-end'|[ti]'/eof'|[oti]'/newline')
        unfinished=false
        ;;

      'i/name')
        from_ast $child value expr_value

        case "$expr_value" in
          or|and|'&&'|'||') unfinished=false; ;;
          *) ast_push_child $expr $child; ;;
        esac
        ;;

      *eof)
        if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          POWSCRIPT_INCOMPLETE_STATE=$state
          exit
        else
          ast_error "unexpected end of file while parsing command."
        fi
        ;;

      *newline)
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

parse_ast_if() { #<<NOSHADOW>>
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

  peek_token -v value -c class
  if [ $class = whitespace ]; then
    skip_token
    peek_token -v value -c class
    backtrack_token
  fi

  if [ $class = name ]; then
    clause_type="$value"
  else
    clause_type=none
  fi

  case "$clause_type" in
    else)
      local else_ast else_block
      make_ast else_ast else

      token_ignore_whitespace
      skip_token
      parse_ast_require_newline "else statement"
      parse_ast_block el else_block

      ast_push_child $else_ast $else_block
      ast_push_child $if_ast $else_ast
      ;;
    elif)
      local elif_ast
      token_ast_ignore_whitespace
      skip_token
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

parse_ast_for() { #<<NOSHADOW>>
  local out="$1"
  local value class elements_ast block_ast

  get_token -v value -c class

  if [ ! "$class" = name ]; then
    ast_error "Expected a variable name in 'for' expression, found a $class token instead."
  else
    require_token name "in"

    make_ast elements_ast elements
    parse_ast_arguments $elements_ast

    parse_ast_block 'for' block_ast

  fi

  make_ast "$out" 'for' "$value" $elements_ast $block_ast
}
noshadow parse_ast_for



parse_ast_conditional() { #<<NOSHADOW>>
  local out="$1"
  local condition
  local initial initial_head initial_value

  parse_ast_expr initial

  from_ast $initial head  initial_head
  from_ast $initial value initial_value

  if [ "$initial_head $initial_value" = "name not" ]; then
    parse_ast_negated_conditional condition
  else
    local value class is_command=true

    peek_token -v value -c class

    if [ $class = name ]; then
      case "$value" in
        is|isnt|'>'|'<'|'<='|'>='|'!='|'='|match)
          is_command=false
          skip_token
          ;;
      esac
    fi

    if $is_command; then
      parse_ast_command_conditional $initial condition
    else
      local left=$initial right
      parse_ast_expr right
      make_ast condition condition $value $left $right
    fi
  fi
  parse_ast_composite_conditional $condition condition

  setvar "$out" $condition
}
noshadow parse_ast_conditional


parse_ast_negated_conditional() { #<<NOSHADOW>>
  local condition out="$1"

  ast_push_state '!'
  parse_ast_conditional condition
  ast_pop_state

  make_ast "$out" condition not $condition
}
noshadow parse_ast_negated_conditional


parse_ast_command_conditional() { #<<NOSHADOW>>
  local cmd="$1" cmd_ast out="$2"

  ast_push_state '=='
  parse_ast_commandcall $cmd cmd_ast
  ast_pop_state

  make_ast "$out" condition 'command' $cmd_ast
  backtrack_token
}
noshadow parse_ast_command_conditional 1


parse_ast_composite_conditional() { #<<NOSHADOW>>
  local value class success=false condition_left="$1" condition_right out="$2"
  peek_token -v value -c class

  if [ "$class" = name ]; then
    case "$value" in
      "and"|"or"|"&&"|"||")
        if ! ast_state_is '!'; then
          skip_token
          parse_ast_conditional condition_right
          success=true
        elif [[ "$value" =~ ('&&'|'||') ]]; then
          skip_token
          parse_ast_negated_conditional condition_right
          success=true
        fi
      ;;
    esac
  fi
  if $success; then
    make_ast "$out" condition $value $condition_left $condition_right
  else
    setvar "$out" $condition_left
  fi
}
noshadow parse_ast_composite_conditional 1

parse_ast_function_definition() { #<<NOSHADOW>>
  local name=$1 out="$2"
  local expr args block

  make_ast expr function-def

  parse_ast_specific_expr list args
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
  case $nl_head in
    newline)
      ;;
    eof)
      if ! ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
        ast_error "unexpected end of file after $1"
      fi
      ;;
    *)
      ast_error "trailing expression after ${1}: $(ast_print $nl) :: $(from_ast $nl head)"
      ;;
  esac
}

parse_ast_block() { #<<NOSHADOW>>
  local state=$1 out="$2"
  local expr child indent_state indent_layers
  local value class token_line ln="0"

  new_ast expr
  ast_set $expr head block

  ast_push_state $state
  ast_new_indentation

  ast_indentation_layers indent_layers
  ast_set $expr value $indent_layers

  indent_state=ok

  while [ ! $indent_state = end ]; do
    peek_token -v value -c class -ls token_line

    ast_test_indentation "$value" $class indent_state

    case $indent_state in
      ok)
        parse_ast_top child
        if [ ! "$child" = -1 ]; then
          ast_push_child $expr $child
          ln="$token_line"
        fi
        ;;
      error*)
        if [ $class = eof ] && ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          POWSCRIPT_INCOMPLETE_STATE="$(ast_last_state)"
          exit
        fi

        local req found or_more=""
        [ $indent_state = error-start ] && or_more=" or more"

        ast_indentation_required req
        ast_count_indentation "$value" $class found
        ast_error "$indent_state : indentation error at line $token_line, expected $req spaces$or_more, found $found."
        ;;
    esac
  done

  ast_pop_state
  ast_pop_indentation
  setvar "$out" $expr
}
noshadow parse_ast_block 1



parse_ast_list() { #<<NOSHADOW>>
  local out="$1"
  local expr child open=true
  local class value

  new_ast expr
  ast_set $expr head list

  while $open; do
    peek_token -v value -c class
    case "$class $value" in
      'special )')
        open=false
        skip_token
        ;;
      'newline '*)
        skip_token
        ;;
      'eof '*)
        if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          POWSCRIPT_INCOMPLETE_STATE="$(ast_last_state)"
          exit
        else
          ast_error "end of file while parsing list"
        fi
        ;;
      *)
        parse_ast_expr child
        ast_push_child $expr $child
        ;;
    esac
  done
  setvar "$out" $expr
}
noshadow parse_ast_list

