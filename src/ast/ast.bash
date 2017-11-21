powscript_source ast/ast_heap.bash #<<EXPAND>>


# ast:parse:try
#
# try parsing an ast expression from the input,
# printing 'top' on success or the last
# parser state on failure.

ast:parse:try() {
  (
    local ast
    POWSCRIPT_INCOMPLETE_STATE=

    trap '
      if [ -n "$POWSCRIPT_INCOMPLETE_STATE" ]; then
        echo "$POWSCRIPT_INCOMPLETE_STATE"
      else
        ast:last-state
      fi
      exit' EXIT

    POWSCRIPT_ALLOW_INCOMPLETE=true ast:parse ast
    exit
  )
}

# ast:parse $out
#
# parse an ast expression form the input,
# storing it in $out.

ast:parse() {
  ast:parse:linestart "$1"
}

ast:error() {
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

# ast:parse:linestart $out
#
# test that there is no indentation before proceeding
# to parse the expression.

ast:parse:linestart() { #<<NOSHADOW>>
  local value class line

  token:get -v value -c class -ls line

  if [ "$class" = whitespace ]; then
    ast:error "indentation error at line $line, unexpected indentation of $value."
  else
    token:backtrack
    ast:parse:top "$1"
  fi
}
noshadow ast:parse:linestart


# ast:parse:top $out
#
# analyze first expression and dispatch to the
# appropriate function based on it.

ast:parse:top() { #<<NOSHADOW>>
  local out="$1"
  local expr expr_head

  ast:parse:expr expr
  ast:from $expr head expr_head

  case $expr_head in
    name)
      local expr_value
      ast:from $expr value expr_value
      case "$expr_value" in
        'if')      ast:parse:if 'if' "$out" ;;
        'for')     ast:parse:for     "$out" ;;
        'math')    ast:parse:math    "$out" ;;
        'while')   ast:parse:while   "$out" ;;
        'switch')  ast:parse:switch  "$out" ;;
        'require') ast:parse:require "$out" ;;
        *)
          if token:next-is special '('; then
            ast:parse:function-definition $expr "$out"
          else
            ast:parse:commandcall $expr "$out"
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
      ast:parse:commandcall $expr "$out"
      ;;
  esac
}
noshadow ast:parse:top


# ast:parse:expr $out
#
# basic expression, which can be a name,
# string, substitution or concatenation.

ast:parse:expr() { #<<NOSHADOW>>
  local out="$1"
  local value class glued
  local root root_head=undefined
  local expression exprnum=0 last_expression

  ast:new root

  while [ $root_head = undefined ]; do
    token:ignore-whitespace
    token:get -v value -c class -g glued

    if ast:state-is math && [ ! $class = eof ] && [ ! $class = newline ]; then
      glued=true
    fi

    if $glued || [ $exprnum = 0 ]; then
      case $class in
        name|string)
          ast:make expression $class "$value"
          ;;
        special)
          case "$value" in
            '$')
              ast:parse:substitution expression
              ;;

            '${')
              ast:parse:curly-substitution expression
              ;;

            '$(')
              ast:parse:command-substitution expression
              ;;
            '$#')
              local next_value next_class
              token:peek -v next_value -c next_class

              if [ $next_class = "name" ] && [[ "$next_value" =~ [a-zA-Z_][a-zA-Z_0-9]* ]]; then
                ast:set $root value $next_value
                root_head=array-length
                token:skip
              else
                make:ast root name '$#'
                root_head=name
              fi
              ;;

            '('|'{')
              local closer
              case $value in
                '(') closer=')'; ;;
                '{') closer='}'; ;;
              esac
              if [ $exprnum -gt 0 ]; then
                root_head=determinable
              else
                ast:push-state $value
                ast:parse:list $closer root
                root_head=list
                ast:pop-state
              fi
              ;;

            ')'|']'|'}')
              local opener
              case $value in
                ')') opener='('; ;;
                ']') opener='['; ;;
                '}') opener='{'; ;;
              esac
              if [ $exprnum -gt 0 ] && { ast:state-is $opener || ast:state-is math; }; then
                root_head=determinable
              else
                ast:make expression string "$value"
              fi
              ;;

            '=')
              if [ $exprnum = 1 ] && ast:is $last_expression name; then
                exprnum=2
                ast:parse:assign $root
                ast:from $root head root_head
              elif [ $exprnum = 2 ] && ast:is $last_expression name; then
                local name op
                ast:children $root name op
                ast:from $op value op

                case "$op" in
                  '+'|'-'|'*'|'/'|'^'|'%')
                    ast:parse:math-assign $root $name "$op"
                    root_head=assign
                    ;;
                  '@')
                    ast:parse:push-assign $root $name
                    root_head=indexing-assign
                    ;;
                  *)
                    ast:make expression string "="
                    ;;
                esac


              else
                ast:make expression string "="
              fi
              ;;
            '[')
              if [ $exprnum = 1 ] && ast:is $last_expression name; then
                local index
                ast:push-state '['
                ast:parse:expr index
                token:require special ']'
                ast:pop-state

                if token:next-is special '='; then
                  token:skip
                  ast:parse:expr expression
                  root_head=indexing-assign
                  ast:push-child $root $index
                  ast:push-child $root $expression
                else
                  local left_bracket right_bracket
                  ast:make left_bracket  name '['
                  ast:make right_bracket name ']'

                  ast:push-child $root $left_bracket
                  ast:push-child $root $index

                  expression=$right_bracket
                  exprnum=3
                fi
              elif [ $exprnum -gt 0 ]; then
                root=determinable
              else
                ast:push-state '['
                ast:parse:list ']' root
                root_head=list
                ast:pop-state
              fi
              ;;

            '+'|'-'|'*'|'/'|'^'|'%')
              if ast:state-is 'math'; then

                if [ $exprnum = 0 ]; then
                  if [ $value = '+' ] || [ $value = '-' ]; then
                    ast:parse:math-unary $root $value
                  else
                    ast:error "$value is not an unary operator"
                  fi

                elif [ $exprnum = 1 ]; then
                  ast:parse:math-binary $root $last_expression "$value"

                else
                  ast:error "trailling $value in math expression"
                fi
                ast:from $root head root_head

              else
                ast:make expression name "$value"
              fi
              ;;

            *)
              ast:make expression name "$value"
              ;;
          esac
          ;;
        newline|eof)
          root_head=$class
          ;;
        *)
          ast:error "token of class $class found when parsing an expression ast"
          ;;
      esac

      if [ $root_head = undefined ]; then
        ast:push-child $root $expression
        exprnum=$((exprnum+1))
        last_expression=$expression
      fi
    else
      root_head=determinable
    fi

    if [ $root_head = determinable ]; then
      if [ $exprnum = 1 ]; then
        ast:clear $root
        root=$last_expression
        ast:from $root head root_head
      else
        root_head=cat
      fi
      token:backtrack
    fi
  done
  ast:set $root head $root_head

  setvar "$out" $root
}
noshadow ast:parse:expr


ast:parse:specific-expr() { #<<NOSHADOW>>
  local expr expr_head required="$1" out="$2"
  ast:parse:expr expr
  ast:from $expr head expr_head

  if [ $expr_head = $required ]; then
    setvar "$out" $expr
  else
   ast:error "Wrong expression: Found a $expr_head when a $required was required"
 fi
}
noshadow ast:parse:specific-expr 1


ast:parse:assign() {
  local expr="$1"
  local assigned_value head
  local value class

  token:peek -v value -c class
  if [ "$class" = special ]; then
    case "$value" in
      '('|'[') head=list-assign ;;
      '{')     head=associative-assign ;;
      *)       head=assign ;;
    esac
  else
    head=assign
  fi
  ast:set $expr head $head
  ast:parse:expr assigned_value
  ast:push-child $expr $assigned_value
}

ast:parse:math-assign() {
  local expr="$1" name="$2" op="$3"
  local name_value right_operand math_expr assigned name_subst

  ast:from $name value name_value

  ast:push-state math
  ast:parse:expr right_operand
  ast:pop-state

  ast:make name_subst simple-substitution "$name_value"
  ast:make math_expr math "$op" $name_subst $right_operand
  ast:make assigned  math-assigned "" $math_expr

  ast:set $expr head assign
  ast:set $expr children "$name $assigned"
}

ast:parse:push-assign() {
  local expr="$1" name="$2"
  local name_value index value

  ast:from $name value name_value

  ast:make index array-length "$name_value"

  ast:parse:expr value
  ast:set $expr children "$name $index $value"
  ast:set $expr head indexing-assign
}

ast:parse:substitution() { #<<NOSHADOW>>
  local subst out="$1"
  local expr value head varname index lb rb aft
  local cat_children cat_array dollar

  ast:parse:expr expr
  ast:all-from "$expr" -v value -h head -@ varname lb index rb aft

  case "$head" in
    name)
      ast:make subst simple-substitution "$value"
      ;;
    cat)
      if ast:is $varname name; then
        if ast:is $lb name '['; then
          ast:from $varname value value
          ast:make subst indexing-substitution "$value" $index
          if [ -n "$aft" ]; then
            if ast:state-is math; then
              ast:error "invalid math expression: $(ast:print $expr)"
            fi
            ast:from $expr children cat_children
            cat_array=( $cat_children )
            ast:make subst cat $subst "${cat_array[@:4]}"
          fi
        else
          ast:set $varname head simple-substitution
          subst=$expr
        fi
      else
        ast:make dollar name '$'
        ast:unshift-child $expr $dollar
        subst=$expr
      fi
      ;;
    *)
      ast:error "unimplemented variable substitution"
      ;;
  esac
  setvar "$out" $subst
}
noshadow ast:parse:substitution


ast:parse:curly-substitution() { #<<NOSHADOW>>
  local out="$1"
  local subst

  ast:push-state '{'
  ast:parse:substitution subst
  token:require special '}'
  ast:pop-state

  setvar "$out" $subst
}
noshadow ast:parse:curly-substitution


ast:parse:command-substitution() { #<<NOSHADOW>>
  local out="$1"
  local cmd call

  ast:make "$out" command-substitution ''

  ast:push-state '('

  ast:parse:expr cmd
  if ast:is $cmd name math; then
    ast:parse:math call
    token:require special ')'
  else
    ast:parse:commandcall $cmd call
  fi
  ast:pop-state

  ast:push-child "${!out}" $call
}
noshadow ast:parse:command-substitution


# ast:parse:commandcall $command $out
#
# parse a command call, consisting of
# a command and a series of space
# separated arguments

ast:parse:commandcall() { #<<NOSHADOW>>
  local command_ast=$1 out="$2"
  local expression child expr_head=none

  ast:make expression call '' $command_ast

  ast:parse:arguments $expression

  setvar "$out" $expression
}
noshadow ast:parse:commandcall 1

ast:parse:arguments() {
  local expr="$1"
  local expr_head=none expr_value child unfinished=true state state_s

  ast:last-state state
  case $state in
    '(')
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
    ast:parse:expr child
    ast:from $child head  expr_head
    ast:from $child value expr_value

    case "$state_s/$expr_head/$expr_value" in
      'c/string/)'|[ti]'/eof/'*|[oti]'/newline/'*)
        unfinished=false
        ;;

      'i/name/'*)
        ast:from $child value expr_value

        case "$expr_value" in
          or|and|'&&'|'||') unfinished=false; ;;
          *) ast:push-child $expr $child; ;;
        esac
        ;;

      */eof/*)
        if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          POWSCRIPT_INCOMPLETE_STATE=$state
          exit
        else
          ast:error "unexpected end of file while parsing command."
        fi
        ;;

      */newline/*)
        ;;

      *)
        ast:push-child $expr $child
        ;;
    esac
  done
}

ast:parse:math-unary() {
  local expr="$1" op="$2"
  local operand value head

  ast:parse:expr operand
  ast:parse:validate-math-operand $operand
  ast:push-child $expr $operand

  ast:set $expr value "$op"
  ast:set $expr head  math
}

ast:parse:math-binary() {
  local expr="$1" left="$2" op="$3"
  local right

  ast:parse:expr right
  ast:parse:validate-math-operand $left
  ast:parse:validate-math-operand $right
  ast:push-child $expr $right

  ast:set $expr value "$op"
  ast:set $expr head  math
}


ast:parse:validate-math-operand() {
  local operand="$1"

  ast:all-from "$operand" -v value -h head

  case "$head" in
    name)
      if [[ "$value" =~ ([a-zA-Z_][a-zA-Z_0-9]*|@) ]]; then
        ast:set $operand head simple-substitution
      elif [[ "$value" =~ [0-9]+ ]]; then
        true
      else
        ast:error "invalid variable name '$value' in math expression"
      fi
      ;;
    *substitution|math)
      ;;
    list)
      local element elements count=0
      ast:from $operand children elements
      for element in $elements; do
        ast:parse:validate-math-operand $element
        count=$((count+1))
      done
      if [ ! $count = 1 ]; then
        ast:error "invalid math expression $(ast:print operand): trailling expressions in parentheses"
      fi
      ;;
    *)
      ast:error "not a valid math expression: $(ast:print operand) :: $head"
      ;;
  esac
}

ast:parse:math() { #<<NOSHADOW>>
  local out="$1"
  local expr math_expr


  ast:push-state math
  ast:parse:expr expr
  ast:pop-state

  ast:parse:validate-math-operand $expr

  ast:make math_expr math-top '' $expr
  setvar "$out" $math_expr
}
noshadow ast:parse:math



# ast:parse:if $block_type $out
#
# parses a if statement, which is
# a conditional expression, followed
# by a newline, block, and possibly an
# else or elif statements

ast:parse:if() { #<<NOSHADOW>>
  local block_type=$1 out="$2"
  local expr conditional block

  ast:new expr
  case "$block_type" in
    if) ast:set $expr head if; ;;
    ef) ast:set $expr head elif; ;;
    *)  ast:error "invalid block type for if expression";;
  esac

  ast:parse:conditional conditional
  ast:parse:require-newline "condition in if statement"
  ast:parse:block $block_type block

  ast:push-child $expr $conditional
  ast:push-child $expr $block

  ast:parse:post-if $expr

  setvar "$out" $expr
}
noshadow ast:parse:if 1

ast:parse:post-if() {
  local if_ast="$1"
  local value class clause_type

  token:peek -v value -c class
  if [ $class = whitespace ]; then
    token:skip
    token:peek -v value -c class
    token:backtrack
  fi

  if [ $class = name ]; then
    clause_type="$value"
  else
    clause_type=none
  fi

  case "$clause_type" in
    else)
      local else_ast else_block
      ast:make else_ast else

      token:ignore-whitespace
      token:skip
      ast:parse:require-newline "else statement"
      ast:parse:block el else_block

      ast:push-child $else_ast $else_block
      ast:push-child $if_ast $else_ast
      ;;
    elif)
      local elif_ast
      token:ignore-whitespace
      token:skip
      ast:parse:if ef elif_ast

      ast:push-child $if_ast $elif_ast
      ;;
    *)
      local end_ast
      ast:new end_ast
      ast:set $end_ast head end_if

      ast:push-child $if_ast $end_ast
      ;;
  esac
}

ast:parse:for() { #<<NOSHADOW>>
  local out="$1"
  local value class elements_ast block_ast

  token:get -v value -c class

  if [ ! "$class" = name ]; then
    ast:error "Expected a variable name in 'for' expression, found a $class token instead."
  else
    token:require name "in"

    ast:make elements_ast elements
    ast:parse:arguments $elements_ast

    ast:parse:block 'for' block_ast

  fi

  ast:make "$out" 'for' "$value" $elements_ast $block_ast
}
noshadow ast:parse:for

ast:is-flag() {
  local expr="$1" minus name extra

  if ast:is $expr cat; then
    ast:children $expr minus name extra
    if ast:is $minus name '-' && ast:is $name name && [ -z "$extra" ]; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

ast:parse:conditional() { #<<NOSHADOW>>
  local out="$1"
  local condition
  local initial initial_head initial_value

  ast:parse:expr initial

  ast:from $initial head  initial_head
  ast:from $initial value initial_value

  if [ "$initial_head $initial_value" = "name not" ]; then
    ast:parse:negated-conditional condition

  elif ast:is-flag $initial; then
    ast:parse:flag-conditional $initial condition

  else
    local value class is_command=true

    token:peek -v value -c class

    if [ $class = name ]; then
      case "$value" in
        is|isnt|'>'|'<'|'<='|'>='|'!='|'='|match)
          is_command=false
          token:skip
          ;;
      esac
    fi

    if $is_command; then
      ast:parse:command-conditional $initial condition
    else
      local left=$initial right
      ast:parse:expr right
      ast:make condition condition $value $left $right
    fi
  fi
  ast:parse:composite-conditional $condition condition

  setvar "$out" $condition
}
noshadow ast:parse:conditional


ast:parse:negated-conditional() { #<<NOSHADOW>>
  local condition out="$1"

  ast:push-state '!'
  ast:parse:conditional condition
  ast:pop-state

  ast:make "$out" condition not $condition
}
noshadow ast:parse:negated-conditional


ast:parse:flag-conditional() { #<<NOSHADOW>>
  local initial="$1" out="$2"
  local minus name flag expr

  ast:children $initial minus name
  ast:from $name value flag
  flag="-$flag"

  ast:parse:expr expr
  ast:make "$out" condition "$flag" $expr
}
noshadow ast:parse:flag-conditional 1


ast:parse:command-conditional() { #<<NOSHADOW>>
  local cmd="$1" cmd_ast out="$2"

  ast:push-state '=='
  ast:parse:commandcall $cmd cmd_ast
  ast:pop-state

  ast:make "$out" condition 'command' $cmd_ast
  token:backtrack
}
noshadow ast:parse:command-conditional 1


ast:parse:composite-conditional() { #<<NOSHADOW>>
  local value class success=false condition_left="$1" condition_right out="$2"
  token:peek -v value -c class

  if [ "$class" = name ]; then
    case "$value" in
      "and"|"or"|"&&"|"||")
        if ! ast:state-is '!'; then
          token:skip
          ast:parse:conditional condition_right
          success=true
        elif [[ "$value" =~ ('&&'|'||') ]]; then
          token:skip
          ast:parse:negated-conditional condition_right
          success=true
        fi
      ;;
    esac
  fi
  if $success; then
    ast:make "$out" condition $value $condition_left $condition_right
  else
    setvar "$out" $condition_left
  fi
}
noshadow ast:parse:composite-conditional 1

ast:parse:function-definition() { #<<NOSHADOW>>
  local name=$1 out="$2"
  local expr args block

  ast:make expr function-def

  ast:parse:specific-expr list args
  ast:parse:require-newline "function definition"
  ast:parse:block fn block

  ast:push-child $expr $name
  ast:push-child $expr $args
  ast:push-child $expr $block

  setvar "$out" $expr
}
noshadow ast:parse:function-definition 1

ast:parse:require-newline() {
  local nl nl_head
  ast:parse:expr nl
  ast:from $nl head nl_head
  case $nl_head in
    newline)
      ;;
    eof)
      if ! ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
        ast:error "unexpected end of file after $1"
      fi
      ;;
    *)
      ast:error "trailing expression after ${1}: $(ast:print $nl) :: $(ast:from $nl head)"
      ;;
  esac
}

ast:parse:block() { #<<NOSHADOW>>
  local state=$1 out="$2"
  local expr child indent_state indent_layers
  local value class token_line ln="0"

  ast:make expr block

  ast:push-state $state
  ast:new-indentation

  ast:indentation-layers indent_layers
  ast:set $expr value $indent_layers

  indent_state=ok

  while [ ! $indent_state = end ]; do
    token:peek -v value -c class -ls token_line

    ast:test-indentation "$value" $class indent_state

    case $indent_state in
      ok)
        ast:parse:top child
        if [ ! "$child" = -1 ]; then
          ast:push-child $expr $child
          ln="$token_line"
        fi
        ;;
      error*)
        if [ $class = eof ] && ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          POWSCRIPT_INCOMPLETE_STATE="$(ast:last-state)"
          exit
        fi

        local req found or_more=""
        [ $indent_state = error-start ] && or_more=" or more"

        ast:indentation-required req
        ast:count-indentation "$value" $class found
        ast:error "$indent_state : indentation error at line $token_line, expected $req spaces$or_more, found $found."
        ;;
    esac
  done

  ast:pop-state
  ast:pop-indentation
  setvar "$out" $expr
}
noshadow ast:parse:block 1



ast:parse:list() { #<<NOSHADOW>>
  local closer="$1" out="$2"
  local expr child open=true
  local class value

  ast:make expr list

  while $open; do
    token:peek -v value -c class
    case "$class $value" in
      "special $closer")
        open=false
        token:skip
        ;;
      'newline '*)
        token:skip
        ;;
      'eof '*)
        if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          POWSCRIPT_INCOMPLETE_STATE="$(ast:last-state)"
          exit
        else
          ast:error "end of file while parsing list"
        fi
        ;;
      *)
        ast:parse:expr child
        ast:push-child $expr $child
        ;;
    esac
  done
  setvar "$out" $expr
}
noshadow ast:parse:list 1

