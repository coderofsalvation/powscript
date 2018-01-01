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
  local right_side

  ast:push-state math
  ast:parse:expr right_side
  ast:pop-state

  ast:set $expr head math-assign
  ast:set $expr value "$op"
  ast:set $expr children "$name $right_side"
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

# ast:parse:concat-assign $expr $name
#
# Parse an AST to be concatenated to a variable
#

ast:parse:concat-assign() {
  local expr="$1" name="$2"
  local name_value value subst concat

  ast:from $name value name_value

  ast:parse:expr value

  ast:set $expr children "$name $value"
  ast:set $expr head concat-assign
}


# ast:parse:assign-sequence $first $out
#
# parse a sequence of assignments, followed by either a newline or command call
#

ast:parse:assign-sequence() { #<<NOSHADOW>>
  local first=$1 out="$2"
  local seq extra cmd

  ast:make seq assign-sequence '' $first

  ast:parse:sequence $seq 'ast:is-assign %' extra

  if [ "$extra" = '-1' ]; then
    setvar "$out" $seq
  else
    ast:parse:command-call $seq $extra cmd
    setvar "$out" $cmd
  fi
}
noshadow ast:parse:assign-sequence 1

ast:is-assign() {
  local expr="$1"
  local expr_head

  ast:from $expr head expr_head

  case $expr_head in
    *assign) return 0 ;;
    *)       return 1 ;;
  esac
}

