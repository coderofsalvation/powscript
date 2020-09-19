# ast:parse:pop $out
#
# Parses an expression of the forms:
#   pop
#   pop <expression>
#
ast:parse:pop() { #<<NOSHADOW>>
  local out="$1"
  local argument argument_head

  ast:parse:expr argument
  ast:from $argument head argument_head

  case $argument_head in
    newline)
      ast:make "$out" pop ''
      ;;

    *)
      ast:make "$out" pop '' $argument
      ast:parse:require-newline 'pop'
      ;;
  esac
}
noshadow ast:parse:pop
