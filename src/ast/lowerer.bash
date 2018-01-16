
ast:lower() { #<<NOSHADOW>>
  local expr="$1" out="$2"

  local VarsInScope=''
  declare -i CurrentScope
  declare -A VarTypes
  CurrentScope=0

  typing:scan $expr

  CurrentScope=0
  ast:lower-scanned $expr "$out"
}
noshadow ast:lower 1

ast:lower-scanned() { #<<NOSHADOW>>
  local expr="$1" out="$2"
  local result
  local expr_head

  ast:from $expr head expr_head

  case $expr_head in
    for-of)
      local var array block
      local array_name at elements

      ast:children $expr var array block

      if ! ast:is $array name; then
        ast:error "for-of expression expected an array's name, got a $(ast:from $array head)"
      fi
      ast:from $array value array_name

      ast:make at name '@'
      ast:make elements indexing-substitution "$array_name" $at

      ast:make result 'for' '' $var $elements $block
      ;;
    for-of-map)
      local key val array block
      local array_name at elements
      local val_assign val_get key_name key_subst
      local newblock block_value block_children

      ast:children $expr key val array block

      if ! ast:is $array name; then
        ast:error "for-of expression expected an array's name, got a $(ast:from $array head)"
      fi
      ast:from $array value array_name

      ast:make at name '@'
      ast:make elements indirect-indexing-substitution "$array_name" $at

      ast:from $key value key_name
      ast:make key_subst simple-substitution "$key_name"
      ast:make val_get indexing-substitution "$array_name" $key_subst
      ast:make val_assign assign '' $val $val_get

      ast:all-from $block -v block_value -c block_children
      ast:make newblock block "$block_value" $val_assign $block_children

      ast:make result 'for' '' $key $elements $newblock
      ;;
    math-assign)
      local var varname value op type

      ast:from $expr value op
      ast:children $expr var value

      ast:from $var value varname
      typing:var-type "$varname" type

      if [ "$PowscriptBackend" = 'bash' ] && [ "$op" = '+' ] && [ "$type" = 'integer' ]; then
        local math_expr

        ast:make math_expr math-assigned "" $value
        ast:make result add-assign "" $var $math_expr

      else
        local math_expr math_assigned subst varname

        ast:from $var value varname

        ast:make subst simple-substitution "$varname"
        ast:make math_expr math "$op" $subst $value
        ast:make math_assigned math-assigned '' $math_expr

        ast:make result assign '' $var $math_assigned
      fi
      ;;
    concat-assign)
      local var varname value type

      ast:children $expr var value

      ast:from $var value varname
      typing:var-type "$varname" type

      if [ "$PowscriptBackend" = 'bash' ] && [ "$type" = string ]; then
        ast:make result add-assign '' $var $value
      else
        result=$expr
      fi
      ;;
    function-def)
      local name args arg_locals block block_lowered

      typing:start-scope
      ast:children $expr name args block

      ast:make-argument-locals $args arg_locals

      ast:lower-scanned $block block_lowered
      ast:unshift-child $block_lowered $arg_locals
      ast:make result function-def '' $name $args $block_lowered

      typing:end-scope
      ;;
    name|math*|string)
      result=$expr
      ;;
    *)
      local expr_value expr_children child lowered_child

      ast:from $expr value expr_value
      ast:from $expr children expr_children

      ast:make result "$expr_head" "$expr_value"

      for child in $expr_children; do
        ast:lower-scanned $child lowered_child
        ast:push-child $result $lowered_child
      done
      ;;
  esac

  setvar "$out" $result
}
noshadow ast:lower-scanned 1

ast:make-argument-locals() { #<<NOSHADOW>>
  local args="$1" out="$2"
  local result assign_expr child args_children
  declare -i count

  ast:make result local

  count=1
  ast:from $args children args_children

  for child in $args_children; do
    ast:make subst simple-substitution $count
    ast:make assign_expr assign '' $child $subst
    ast:push-child $result $assign_expr
    count+=1
  done

  setvar "$out" $result
}
noshadow ast:make-argument-locals 1


typing:start-scope() {
  CurrentScope+=1
}

typing:end-scope() {
  return
}


typing:set-type() {
  local var="$1" type="$2"
  VarTypes["${var}|$CurrentScope"]=$type
}

typing:var-type() {
  setvar "$2" "${VarTypes[${1}|$CurrentScope]}"
}

typing:declare-all() {
  local expr="$1" type="$2"
  local var child expr_children

  ast:from $expr children expr_children

  for child in $expr_children; do
    typing:declared-name $child var
    typing:set-type $var $type
  done
}

typing:declared-name() { #<<NOSHADOW>>
  local expr="$1" out="$2"
  local expr_head

  ast:from $expr head expr_head
  case $expr_head in
    name)
      ;;
    *assign)
      ast:children $expr expr
      ;;
    *)
      ast:error "invalid expression in local/declare: $(ast:print $expr)"
      ;;
  esac

  ast:from $expr value "$out"
}
noshadow typing:declared-name 1


typing:scan() {
  local expr="$1"
  local expr_head

  ast:from $expr head expr_head

  case $expr_head in
    declare)
      local type

      ast:from $expr value type

      case "$type" in
        integer|string|array|map|function) ;;
        *) ast:error "in declare statement: invalid type $type" ;;
      esac

      typing:declare-all $expr $type
      ;;

    local)
      typing:declare-all $expr string
      ;;

    function-def)
      local _ args block
      ast:children $expr _ args block

      typing:start-scope

      typing:declare-all $args string
      typing:scan $block

      typing:end-scope
      ;;

    *)
      local child expr_children

      ast:from $expr children expr_children

      for child in $expr_children; do
        typing:scan $child
      done
      ;;
  esac
}

