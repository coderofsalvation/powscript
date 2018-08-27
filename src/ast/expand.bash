ast:parse:expand() { #<<NOSHADOW>>
  local out="$1"
  local block

  ast:parse:require-newline "expand"
  ast:parse:block "ex" block
  ast:make "$out" expand "" $block
}
noshadow ast:parse:expand
