declare -gA Asts

Asts[index]=0
Asts[length]=0
Asts[required-indent]=0

powscript_source ast/indent.bash #<<EXPAND>>
powscript_source ast/states.bash #<<EXPAND>>

ast:new() { #<<NOSHADOW>>
  local index="${Asts[index]}"
  local length="${Asts[length]}"

  setvar "$1" "$index"

  Asts[head-$index]=
  Asts[value-$index]=
  Asts[children-$index]=

  if [ ! $index = $length ]; then
    Asts[index]=$(($index+1))
  else
    Asts[index]=$(($length+1))
  fi
  Asts[length]=$(($length+1))
}
noshadow ast:new

ast:make() {
  local __newast __newchild
  ast:new __newast
  ast:set "$__newast" head  "$2"
  ast:set "$__newast" value "$3"
  for __newchild in ${@:4}; do
    ast:push-child "$__newast" $__newchild
  done
  setvar "$1" "$__newast"
}

ast:from() {
  setvar "$3" "${Asts["$2-$1"]}"
}

ast:all-from() {
  local __af_expr="$1"
  shift

  while [ $# -gt 0 ]; do
    case "$1" in
      -e|--expr)
        setvar "$2" $__af_expr
        shift 2
        ;;
      -v|--value)
        ast:from $__af_expr value "$2"
        shift 2
        ;;
      -h|--head)
        ast:from $__af_expr head "$2"
        shift 2
        ;;
      -c|--children)
        ast:from $__af_expr children "$2"
        shift 2
        ;;
      -@|--@children)
        ast:children $__af_expr "${@:2}"
        shift $#
        ;;
      *)
        ast:error "Invalid flag $1, expected -[evhc@]"
        ;;
    esac
  done
}

ast:set() {
  Asts["$2-$1"]="$3"
}

ast:is() {
  local ast_head ast_value res=false
  ast:from $1 head  ast_head
  ast:from $1 value ast_value

  case $# in
    2)
      [ $ast_head = "$2" ] && res=true
      ;;
    3)
      [ $ast_head = "$2" ] && [ "$ast_value" = "$3" ] && res=true
      ;;
  esac
  $res
}


ast:push-child() {
  Asts["children-$1"]="${Asts["children-$1"]} $2"
}

ast:unshift-child() {
  Asts["children-$1"]="$2 ${Asts["children-$1"]}"
}

ast:children() { #<<NOSHADOW>>
  local ast="$1"
  local ast_children children_array child i

  ast:from $ast children ast_children
  children_array=( $ast_children )

  i=0
  for child_name in ${@:2}; do
    setvar "$child_name" ${children_array[$i]}
    i=$((i+1))
  done
}
noshadow ast:children 1 @


ast:clear() {
  unset Asts["value-$1"]
  unset Asts["head-$1"]
  unset Asts["children-$1"]
}

ast:clear-all() {
  unset Asts
  declare -gA Asts

  Asts[index]=0
  Asts[length]=0
  Asts[required-indent]=0
}

ast:print() {
  printf '`'
  ast:print-child "$1" "$2"
  echo '`'
}

ast:print-child() {
  local ast=$1 indent=
  local ast_head ast_value ast_children
  ast:from $ast head     ast_head
  ast:from $ast value    ast_value
  ast:from $ast children ast_children

  local child_array=( $ast_children )

  case $ast_head in
    name)
      printf "%s" "$ast_value"
      ;;
    cat)
      local child
      for child in ${child_array[@]:0:$((${#child_array[@]}-1))}; do
        ast:print-child $child
      done
      ast:print-child ${child_array[${#child_array[@]}-1]}
      ;;
    string)
      printf "'%s'" "$ast_value"
      ;;
    call)
      local command=${child_array[0]}
      local argument

      ast:print-child $command
      for argument in ${child_array[@]:1}; do
        printf ' '
        ast:print-child $argument
      done
      ;;
    assign)
      local name=${child_array[0]} value=${child_array[1]}
      ast:print-child $name
      printf '='
      ast:print-child $value
      ;;
    indexing-assign)
      local name=${child_array[0]} index=${child_array[1]} value=${child_array[2]}
      ast:print-child $name
      printf '['
      ast:print-child $index
      printf ']='
      ast:print-child $value
      ;;
    simple-substitution)
      printf '$%s' "$ast_value"
      ;;
    indexing-substitution)
      printf '${%s[' "$ast_value"
      ast:print-child ${child_array[0]}
      printf ']}'
      ;;
    command-substitution)
      printf '$('
      ast:print-child ${child_array[0]}
      printf ')'
      ;;
    math-top)
      printf 'math '
      ast:print-child ${child_array[0]}
      ;;
    math)
      if [ -n "${child_array[1]}" ]; then
        ast:print-child ${child_array[0]}
        printf '%s' "$ast_value"
        ast:print-child ${child_array[1]}
      else
        printf '%s' "$ast_value"
        ast:print-child ${child_array[0]}
      fi
      ;;
    math-assigned)
      ast:print ${child_array[0]}
      ;;
    array-length)
      printf '$#%s' "$ast_value"
      ;;
    function-def)
      local name=${child_array[0]} args=${child_array[1]} block=${child_array[2]}

      ast:print-child $name
      ast:print-child $args
      echo
      ast:print-child $block
      ;;
    if|elif)
      printf '%s ' $ast_head
      ast:print-child ${child_array[0]}
      echo
      ast:print-child ${child_array[1]}
      ast:print-child ${child_array[2]}
      ;;
    else)
      printf 'else\n'
      ast:print-child ${child_array[0]}
      ast:print-child ${child_array[1]}
      ;;
    end_if)
      ;;
    condition)
      case $ast_value in
        command)
          ast:print-child ${child_array[0]}
          ;;
        not|-*)
          printf '%s ' "$ast_value"
          ast:print-child ${child_array[0]}
          ;;
        *)
          ast:print-child ${child_array[0]}
          printf '%s' "$ast_value"
          ast:print-child ${child_array[1]}
          ;;
      esac
      ;;
    for)
      printf 'for %s in' $ast_value
      ast:print-child ${child_array[0]}
      echo
      ast:print-child ${child_array[1]}
      ;;
    list)
      local element

      printf '( '
      for element in "${child_array[@]}"; do
        ast:print-child $element
        printf ' '
      done
      printf ')'
      ;;
    block)
      local statement

      for statement in "${child_array[@]}"; do
        printf "%$((ast_value*2)).s" ''
        ast:print-child $statement
        echo
      done
      ;;
  esac
}

