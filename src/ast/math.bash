# ast:parse:math $out
#
# Entry point for parsing a math expression.
#

ast:parse:math() { #<<NOSHADOW>>
  local out="$1"
  local expr math_expr
  local float_precision

  AST_MATH_MODE=true ast:parse:expr expr

  ast:parse:validate-math-operand $expr

  if token:next-is name && ! ${NOBC-false}; then
    token:get -v float_precision
    if [[ "$float_precision" =~ [0-9]+ ]]; then
      ast:make math_expr math-float "$float_precision" $expr
    else
      ast:error "expected number for floating point precision in math expression, got $float_precision"
    fi
  else
    ast:make math_expr math-top '' $expr
  fi

  setvar "$out" $math_expr
}
noshadow ast:parse:math


# ast:parse:math-unary $expr $op
#
# Parse math expressions of the forms -expr or +expr.
#

ast:parse:math-unary() {
  local expr="$1" op="$2"
  local operand value head

  ast:parse:expr operand
  ast:parse:validate-math-operand $operand
  ast:push-child $expr $operand

  ast:set $expr value "$op"
  ast:set $expr head  math
}

# ast:parse:math-binary $expr $left $op
#
# Parse math expressions of the form expr op expr.
#

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


# ast:parse:validate-math-operand $operand
#
# Checks that the operand is a valid math expression, which can be
#  - var, becoming $var
#  - $var, $(command ...), $(math expr), expr
#  - (expr), [expr], {expr}
# Anything else is an error.
#

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

