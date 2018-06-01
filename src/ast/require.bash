ast:parse:require() { #<<NOSHADOW>>
  local out="$1"
  local file

  ast:parse:expr file
  ast:parse:require-newline 'require'

  ast:make "$out" require '' $file
}
noshadow ast:parse:require
