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
    and)
      ast:print-child ${child_array[0]}
      printf " and "
      ast:print-child ${child_array[1]}
      ;;
    indexing-assign)
      local name=${child_array[0]} index=${child_array[1]} value=${child_array[2]}
      ast:print-child $name
      printf '['
      ast:print-child $index
      printf ']='
      ast:print-child $value
      ;;
    math-assign)
      ast:print-child ${child_array[0]}
      printf '%s=' $ast_value
      ast:print-child ${child_array[1]}
      ;;
    concat-assign)
      ast:print-child ${child_array[0]}
      printf '&='
      ast:print-child ${child_array[1]}
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
      ast:print-child ${child_array[0]}
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
          printf ' %s ' "$ast_value"
          ast:print-child ${child_array[1]}
          ;;
      esac
      ;;
    for)
      printf 'for '
      ast:print-child ${child_array[0]}
      printf ' in '
      ast:print-child ${child_array[1]}
      echo
      ast:print-child ${child_array[2]}
      ;;
    for-of)
      printf 'for '
      ast:print-child ${child_array[0]}
      printf ' of '
      ast:print-child ${child_array[1]}
      echo
      ast:print-child ${child_array[2]}
      ;;
    switch|case|while)
      printf '%s' "$ast_head"
      ast:print-child ${child_array[0]}
      echo
      ast:print-child ${child_array[1]}
      ;;
    await*)
      local then

      printf 'await '
      ast:print-child ${child_array[0]}
      printf ' then'

      case "$ast_head" in
        await-for)
          then=2
          printf ' for '
          ast:print-child ${child_array[1]}
          echo
          ;;
        await-pipe)
          then=1
          printf ' |\n'
          ;;
        await-then)
          then=1
          echo
          ;;
      esac

      ast:print-child ${child_array[$then]}

      if [ -n "${child_array[$((then+1))]}" ]; then
        printf 'when done\n'
        ast:print-child ${child_array[$((then+1))]}
      fi
      ;;
    pipe)
      ast:print-child ${child_array[0]}
      printf " | "
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
    elements)
      local element

      for element in "${child_array[@]}"; do
        ast:print-child $element
        printf ' '
      done
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


