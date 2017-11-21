# ast:parse:function-definition $name $out
#
# Parses an expression of the form:
#   name(...vars...)
#     <block>
#

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

