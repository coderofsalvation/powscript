# ast:parse:assign $expr
#
# Parse an AST representing the attribution
# of a value to a name.
# Can be of the type:
#  - var=single-value
#  - var=(...)
#  - var=[...]
#  - var={}
# The given $expr is an undefined AST
# with the var name as a child, which
# will be transformed into the assign.
#

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


# ast:parse:math-assign $expr $name $op
#
# Parse an math AST to be attributed to a
# variable.
#

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


# ast:parse:push-assign $expr $name
#
# Parse an AST to be pushed at the
# end of an array.
#

ast:parse:push-assign() {
  local expr="$1" name="$2"
  local name_value index value

  ast:from $name value name_value

  ast:make index array-length "$name_value"

  ast:parse:expr value
  ast:set $expr children "$name $index $value"
  ast:set $expr head indexing-assign
}

