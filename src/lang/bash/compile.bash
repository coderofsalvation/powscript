powscript_source lang/bash/interactive.bash #<<EXPAND>>

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

    if|elif)
      local expr_children
      local condition block post_if

      from_ast $expr children expr_children
      expr_children=( $expr_children )

      bash_compile ${expr_children[0]} condition
      bash_compile ${expr_children[1]} block
      bash_compile ${expr_children[2]} post_if

      setvar "$out" "$expr_head $condition; then"$'\n'"${block:2:$((${#block}-4))}"$'\n'"$post_if"
      ;;
    else)
      local expr_children
      local block

      from_ast $expr children expr_children
      expr_children=( $expr_children )

      bash_compile ${expr_children[0]} block

      setvar "$out" "else"$'\n'"${block:2:$((${#block}-4))}"$'\n'"fi"
      ;;

    end_if)
      setvar "$out" "fi"
      ;;

    simple-substitution)
      local name
      from_ast $expr value name
      setvar "$out" "\"\${$name}\""
      ;;

    indexing-substitution)
      local name index expr_children

      from_ast $expr children expr_children
      expr_children=( $expr_children )

      from_ast $expr value name
      bash_compile ${expr_children[0]} index

      setvar "$out" "\"\${$name[$index]}\""
      ;;
    command-substitution)
      local call_ast call

      from_ast $expr children call_ast

      bash_compile $call_ast call

      setvar "$out" '$('"$call"')'
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

    list)
      local expr_children child_ast child result

      from_ast $expr children expr_children

      result="( "
      for child_ast in $expr_children; do
        bash_compile $child_ast child
        result="$result$child "
      done

      setvar "$out" "$result)"
      ;;

    function-def)
      local name args_ast arg_assign_ast argval_ast block_ast block
      local args arg argval argnum locals_ast argname_ast

      from_ast $expr children expr_children
      expr_children=( $expr_children )

      bash_compile ${expr_children[0]} name

      args_ast=${expr_children[1]}
      block_ast=${expr_children[2]}


      new_ast locals_ast
      ast_set $locals_ast head local

      from_ast $args_ast children args


      argnum=1
      for arg in $args; do
        make_ast argval_ast simple-substitution $argnum
        make_ast arg_assign_ast assign '' $arg $argval_ast
        ast_push_child $locals_ast $arg_assign_ast
        argnum=$((argnum+1))
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

    condition)
      local op left right quoted=no
      from_ast $expr value op
      from_ast $expr children expr_children
      expr_children=( $expr_children )

      case "$op" in
        command)
          bash_compile ${expr_children[0]} "$out"
          ;;
        not)
          bash_compile ${expr_children[0]} right
          setvar "$out" "! $right"
          ;;
        *)
          bash_compile ${expr_children[0]} left
          bash_compile ${expr_children[1]} right

          case "$op" in
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
      ;;
  esac
}
noshadow bash_compile 1
