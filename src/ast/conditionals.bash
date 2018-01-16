# ast:parse:if $block_type $out
#
# Parses an expression of the form:
#   if <conditional>
#     <block>
#   elif <conditional> # optional, as many as we want
#     <block>
#   else # optional, only one allowed
#     <block>
#

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


# ast:parse:post-if $if_ast
#
# Checks if the if expressions is continued in
# an elif or else and parses accordingly.
#

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


# ast:parse:while $out
#
# Parses and expression of the form:
#   while <expr>
#     <block>
#

ast:parse:while() { #<<NOSHADOW>>
  local out="$1"
  local condition block

  ast:parse:conditional condition
  ast:parse:require-newline 'while statement'
  ast:parse:block wh block

  ast:make "$out" 'while' '' $condition $block
}
noshadow ast:parse:while


# ast:parse:for $out
#
# Parses an expression of the form:
#   for <var> in <expr>
#     <block>
#
# or
#   for <var> of <expr>
#     <block>
#
# or
#  for <var>,<var> of <expr>
#    <block>
#

ast:parse:for() { #<<NOSHADOW>>
  local out="$1"
  local value value2 class class2 result
  local var_ast var2_ast elements_ast block_ast

  token:get -v value -c class

  if [ ! "$class" = name ]; then
    ast:error "Expected a variable name in 'for' expression, found a $class token instead."
  else
    if token:next-is name 'in'; then
      token:skip

      ast:make var_ast name "$value"

      ast:make elements_ast elements
      ast:parse:sequence $elements_ast

      ast:parse:block 'for' block_ast

      ast:make result 'for' '' $var_ast $elements_ast $block_ast

    elif token:next-is name 'of'; then
      token:skip

      ast:make var_ast name "$value"

      ast:parse:expr elements_ast
      ast:parse:require-newline 'for-of'

      ast:parse:block 'for' block_ast

      ast:make result 'for-of' '' $var_ast $elements_ast $block_ast

    elif token:next-is special ','; then
      token:skip
      token:get -v value2 -c class2

      if [ ! "$class" = name ]; then
        ast:error "Expected a variable name in 'for-of' expression, found a $class2 token instead."
      fi

      token:require name 'of'

      ast:make var_ast  name "$value"
      ast:make var2_ast name "$value2"

      ast:parse:expr elements_ast
      ast:parse:require-newline 'for-of'

      ast:parse:block 'for' block_ast

      ast:make result 'for-of-map' '' $var_ast $var2_ast $elements_ast $block_ast
    else
      ast:error "expected 'in', 'of' or ',' after variable name in for expression, found a ${class}: $value"
    fi
  fi

  setvar "$out" $result
}
noshadow ast:parse:for


# ast:parse:switch $out
#
# Parses expressions of the form:
#  switch <expr>
#    case <expr> # at least one
#      <block>
#

ast:parse:switch() { #<<NOSHADOW>>
  local out="$1"
  local value cases_block case_ast cases
  local count

  ast:parse:expr value
  ast:parse:require-newline "switch statement"
  ast:parse:block swt cases_block

  ast:from $cases_block children cases

  for case_ast in $cases; do
    if ! ast:is $case_ast 'case'; then
      ast:error "expected case block in switch statement, found $(ast:from $case_ast head)"
    fi
  done

  ast:make "$out" switch '' $value $cases_block
}
noshadow ast:parse:switch


# ast:parse:case
#
# Parses the case blocks from switch statements
#

ast:parse:case() { #<<NOSHADOW>>
  local out="$1"
  local pattern block

  if ! ast:state-is swt; then
    ast:error "case blocks must be inside switch blocks"
  fi

  ast:parse:pattern pattern
  ast:parse:require-newline "case statement"
  ast:parse:block cs block

  ast:make "$out" 'case' '' $pattern $block
}
noshadow ast:parse:case


# ast:parse:conditional $out
#
# Parses an expression of the form:
#   * -flag <expr>
#   * <expr> <comparison> <expr>
#   * not <conditional>
#   * <conditional> and/or <conditional>
#

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

    if [ $class = name ] || [ $class = special ]; then
      case "$value" in
        is|isnt|'>'|'<'|'<='|'>='|'!='|'='|'=='|match)
          is_command=false
          token:skip
          ;;
      esac
    fi

    if $is_command; then
      ast:parse:command-conditional $initial condition
    else
      local left=$initial right
      if [ "$value" = match ]; then
        ast:parse:pattern right
      else
        ast:parse:expr right
      fi
      ast:make condition condition $value $left $right
    fi
  fi
  ast:parse:composite-conditional $condition condition

  setvar "$out" $condition
}
noshadow ast:parse:conditional


# ast:parse:negated-conditional $out
#
# Parses a conditional and returns a negation of it.
#

ast:parse:negated-conditional() { #<<NOSHADOW>>
  local condition out="$1"

  ast:push-state '!'
  ast:parse:conditional condition
  ast:pop-state

  ast:make "$out" condition not $condition
}
noshadow ast:parse:negated-conditional


# ast:parse:flag-conditional
#
# Parses a conditional of the form -flag <expr>
#

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


# ast:parse:command-conditional
#
# Parses a command call as a conditional
#

ast:parse:command-conditional() { #<<NOSHADOW>>
  local cmd="$1" cmd_ast out="$2"
  local cmd_head assigns value class

  ast:from $cmd head cmd_head

  ast:push-state '=='
  case $cmd_head in
    *assign)
      ast:parse:assign-sequence $cmd cmd_ast
      ;;
    *)
      ast:make assigns assign-sequence
      ast:parse:command-call $assigns $cmd cmd_ast
      ;;
  esac
  ast:pop-state

  ast:make "$out" condition 'command' $cmd_ast
  token:backtrack
}
noshadow ast:parse:command-conditional 1


# ast:parse:composite-conditional $condition_left $out
#
# Parses a conditional of the form <conditional> and/or <conditional>
#

ast:parse:composite-conditional() { #<<NOSHADOW>>
  local condition_left="$1" condition_right out="$2"
  local value class success=false

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

