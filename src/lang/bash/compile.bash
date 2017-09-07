powscript_source lang/bash/interactive.bash

bash_compile() {
  local expr=$1 out="$2"
  local expr_head expr_value expr_children

  from_ast $expr head expr_head

  case "$expr_head" in
    name)
      from_ast $expr value "$out"
      ;;

    string)
      from_ast $expr value expr_value
      setvar "$out" "'$expr_value'"
      ;;

    cat)
      local child compiled result=""
      from_ast $expr children expr_children
      for child in $expr_children; do
        bash_compile $child compiled
        result="$result$compiled"
      done
      setvar "$out" "$result"
      ;;

    call)
      local command argument compiled result
      from_ast $expr children expr_children
      expr_children=( $expr_children )

      bash_compile ${expr_children[0]} result

      for argument in ${expr_children[@]:1}; do
        bash_compile $argument compiled
        result="$result $compiled"
      done
      setvar "$out" "$result"
      ;;

    assign)
      local name value
      from_ast $expr children expr_children
      expr_children=( $expr_children )

      bash_compile ${expr_children[0]} name
      bash_compile ${expr_children[1]} value

      setvar "$out" "$name=$value"
      ;;

    function-def)
      local name args_ast block_ast block
      local args arg locals_ast argname_ast

      from_ast $expr children expr_children
      expr_children=( $expr_children )

      bash_compile ${expr_children[0]} name

      args_ast=${expr_children[1]}
      block_ast=${expr_children[2]}


      parse_ast locals_ast <<< "local"

      from_ast $args_ast children args

      for arg in $args; do
        ast_push_child $local_arg $arg
      done
      ast_unshift_child $block_ast $locals_ast

      bash_compile $block_ast block

      setvar "$out" "$name() $block"
      ;;

    local)
      local result="local" child_ast child
      from_ast $expr children expr_children

      for child_ast in $expr_children; do
        bash_compile $child_ast child
        result="$result $child"
      done

      setvar "$out" "$result"
      ;;
    block)
      local child_ast child result
      from_ast $expr children expr_children

      result='{'
      for child_ast in $expr_children; do
        bash_compile $child_ast child
        result="$result"$'\n'"$child"
      done
      result="$result"$'\n}'

      setvar "$out" "$result"
      ;;

    binary-test)
      local op left right quoted=no
      from_ast $expr children expr_children
      expr_children=( $expr_children )

      bash_compile ${expr_children[1]} left
      bash_compile ${expr_children[2]} right

      case "${expr_children[0]}" in
        'is'|'=')  op='='    quoted=single ;;
        '>')       op='-gt'  quoted=single ;;
        '>=')      op='-ge'  quoted=single ;;
        '<')       op='-lt'  quoted=single ;;
        '<=')      op='-le'  quoted=single ;;
        'match')   op='=~'   quoted=double ;;
        'and')     op='&&' ;;
        'or')      op='||' ;;
      esac

      case $quoted in
        double) setvar "$out" "[[ $left $op $right ]]" ;;
        single) setvar "$out"  "[ $left $op $right ]"  ;;
        no)     setvar "$out"    "$left $op $right"    ;;
      esac
      ;;
  esac
}
noshadow bash_compile 1
