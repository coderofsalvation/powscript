declare -gA Asts

Asts[index]=0
Asts[length]=0
Asts[required-indent]=0

powscript_source ast/ast_indent.bash #<<EXPAND>>
powscript_source ast/ast_states.bash #<<EXPAND>>

new_ast() { #<<NOSHADOW>>
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
noshadow new_ast

make_ast() {
  local __newast __newchild
  new_ast __newast
  ast_set "$__newast" head  "$2"
  ast_set "$__newast" value "$3"
  for __newchild in ${@:4}; do
    ast_push_child "$__newast" $__newchild
  done
  setvar "$1" "$__newast"
}

from_ast() {
  setvar "$3" "${Asts["$2-$1"]}"
}

ast_set() {
  Asts["$2-$1"]="$3"
}

ast_set_to_overwrite() {
  Asts[index]="$1"
}

ast_is() {
  local ast_head ast_value
  from_ast $1 head  ast_head
  from_ast $1 value ast_value

  case $# in
    2)
      [ $ast_head = "$2" ]
      ;;
    3)
      [ $ast_head = "$2" ] && [ "$ast_value" = "$3" ]
      ;;
  esac
}


ast_push_child() {
  Asts["children-$1"]="${Asts["children-$1"]} $2"
}

ast_unshift_child() {
  Asts["children-$1"]="$2 ${Asts["children-$1"]}"
}

ast_children() { #<<NOSHADOW>>
  local ast="$1" ast_children children_array child i
  from_ast $ast children ast_children
  children_array=( $ast_children )

  i=0
  for child_name in ${@:2}; do
    setvar "$child_name" ${children_array[$i]}
    i=$((i+1))
  done
}
noshadow ast_children 1 @


ast_clear() {
  unset Asts["value-$1"]
  unset Asts["head-$1"]
  unset Asts["children-$1"]
}

ast_clear_all() {
  unset Asts
  declare -gA Asts

  Asts[index]=0
  Asts[length]=0
  Asts[required-indent]=0
}

ast_print() {
  printf '`'
  ast_print_child "$1" "$2"
  echo '`'
}

ast_print_child() {
  local ast=$1 indent=
  local ast_head ast_value ast_children
  from_ast $ast head     ast_head
  from_ast $ast value    ast_value
  from_ast $ast children ast_children

  local child_array=( $ast_children )

  case $ast_head in
    name)
      printf "%s" "$ast_value"
      ;;
    cat)
      local child
      for child in ${child_array[@]:0:$((${#child_array[@]}-1))}; do
        ast_print_child $child
      done
      ast_print_child ${child_array[${#child_array[@]}-1]}
      ;;
    string)
      printf "'%s'" "$ast_value"
      ;;
    call)
      local command=${child_array[0]}
      local argument

      ast_print_child $command
      for argument in ${child_array[@]:1}; do
        printf ' '
        ast_print_child $argument
      done
      ;;
    assign)
      local name=${child_array[0]} value=${child_array[1]}
      ast_print_child $name
      printf '='
      ast_print_child $value
      ;;
    indexing-assign)
      local name=${child_array[0]} index=${child_array[1]} value=${child_array[2]}
      ast_print_child $name
      printf '['
      ast_print_child $index
      printf ']='
      ast_print_child $value
      ;;
    simple-substitution)
      printf '$%s' "$ast_value"
      ;;
    indexing-substitution)
      printf '${%s[' "$ast_value"
      ast_print_child ${child_array[0]}
      printf ']}'
      ;;
    command-substitution)
      printf '$('
      ast_print_child ${child_array[0]}
      printf ')'
      ;;
    function-def)
      local name=${child_array[0]} args=${child_array[1]} block=${child_array[2]}

      ast_print_child $name
      ast_print_child $args
      echo
      ast_print_child $block
      ;;
    list)
      local element

      printf '( '
      for element in "${child_array[@]}"; do
        ast_print_child $element
        printf ' '
      done
      printf ')'
      ;;

    block)
      local statement

      for statement in "${child_array[@]}"; do
        printf "%$((ast_value*2)).s" ''
        ast_print_child $statement
        echo
      done
      ;;
  esac
}

