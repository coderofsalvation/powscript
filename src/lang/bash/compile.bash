powscript_source lang/bash/interactive.bash #<<EXPAND>>

bash:compile() { #<<NOSHADOW>>
  local expr=$1 out="$2"
  local expr_head expr_value expr_children

  ast:from $expr head expr_head

  case "$expr_head" in
    name)
      ast:from $expr value "$out"
      ;;

    string)
      ast:from $expr value expr_value
      setvar "$out" "'$expr_value'"
      ;;

    cat)
      local child compiled result=""
      ast:from $expr children expr_children
      for child in $expr_children; do
        bash:compile $child compiled
        result="$result$compiled"
      done
      setvar "$out" "$result"
      ;;

    if|elif)
      local expr_children
      local condition block post_if

      ast:from $expr children expr_children
      expr_children=( $expr_children )

      bash:compile ${expr_children[0]} condition
      bash:compile ${expr_children[1]} block
      bash:compile ${expr_children[2]} post_if

      setvar "$out" "$expr_head $condition; then"$'\n'"${block:2:-2}"$'\n'"$post_if"
      ;;
    else)
      local expr_children
      local block

      ast:from $expr children expr_children
      expr_children=( $expr_children )

      bash:compile ${expr_children[0]} block

      setvar "$out" "else"$'\n'"${block:2:-2}"$'\n'"fi"
      ;;

    end_if)
      setvar "$out" "fi"
      ;;

    for)
      local varname elements_ast block_ast
      local elements block

      ast:from $expr value varname
      ast:children $expr elements_ast block_ast

      bash:compile $elements_ast elements
      bash:compile $block_ast block

      setvar "$out" "for $varname in $elements; do"$'\n'"${block:2:-2}"$'\ndone'
      ;;

    elements)
      local e elements r result

      ast:from $expr children elements

      for e in $elements; do
        bash:compile $e r
        result="$result$r "
      done

      setvar "$out" "${result:0:-1}"
      ;;

    simple-substitution)
      local name
      ast:from $expr value name
      setvar "$out" "\"\${$name}\""
      ;;

    indexing-substitution)
      local name index expr_children

      ast:from $expr children expr_children
      expr_children=( $expr_children )

      ast:from $expr value name
      bash:compile ${expr_children[0]} index

      setvar "$out" "\"\${$name[$index]}\""
      ;;
    command-substitution)
      local call_ast call

      ast:from $expr children call_ast

      bash:compile $call_ast call

      setvar "$out" '$('"$call"')'
      ;;

    call)
      local command argument compiled result
      ast:from $expr children expr_children
      expr_children=( $expr_children )

      bash:compile ${expr_children[0]} result

      for argument in ${expr_children[@]:1}; do
        bash:compile $argument compiled
        result="$result $compiled"
      done
      setvar "$out" "$result"
      ;;

    assign)
      local name value
      ast:from $expr children expr_children
      expr_children=( $expr_children )

      bash:compile ${expr_children[0]} name
      bash:compile ${expr_children[1]} value

      setvar "$out" "$name=$value"
      ;;

    indexing-assign)
      local name index value
      ast:from $expr children expr_children
      expr_children=( $expr_children )

      bash:compile ${expr_children[0]} name
      bash:compile ${expr_children[1]} index
      bash:compile ${expr_children[2]} value

      setvar "$out" "$name[$index]=$value"
      ;;
    list)
      local expr_children child_ast child result

      ast:from $expr children expr_children

      result="( "
      for child_ast in $expr_children; do
        bash:compile $child_ast child
        result="$result$child "
      done

      setvar "$out" "$result)"
      ;;

    function-def)
      local name args_ast arg_assign_ast argval_ast block_ast block
      local args arg argval argnum locals_ast argname_ast

      ast:from $expr children expr_children
      expr_children=( $expr_children )

      bash:compile ${expr_children[0]} name

      args_ast=${expr_children[1]}
      block_ast=${expr_children[2]}

      ast:make locals_ast local

      ast:from $args_ast children args

      argnum=1
      for arg in $args; do
        ast:make argval_ast simple-substitution $argnum
        ast:make arg_assign_ast assign '' $arg $argval_ast
        ast:push-child $locals_ast $arg_assign_ast
        argnum=$((argnum+1))
      done
      ast:unshift-child $block_ast $locals_ast

      bash:compile $block_ast block

      setvar "$out" "$name() $block"
      ;;

    local)
      local result="local" child_ast child
      ast:from $expr children expr_children

      for child_ast in $expr_children; do
        bash:compile $child_ast child
        result="$result $child"
      done

      setvar "$out" "$result"
      ;;
    block)
      local child_ast child result
      ast:from $expr children expr_children

      result='{'
      for child_ast in $expr_children; do
        bash:compile $child_ast child
        result="$result"$'\n'"$child"
      done
      result="$result"$'\n}'

      setvar "$out" "$result"
      ;;

    condition)
      local op left right quoted=no
      ast:from $expr value op
      ast:from $expr children expr_children
      expr_children=( $expr_children )

      case "$op" in
        command)
          bash:compile ${expr_children[0]} left
          setvar "$out" "$left"
          ;;
        not)
          bash:compile ${expr_children[0]} right
          setvar "$out" "! $right"
          ;;
        *)
          bash:compile ${expr_children[0]} left
          bash:compile ${expr_children[1]} right

          case "$op" in
            'is'|'=')     op='='    quoted=single ;;
            'isnt'|'!=')  op='!='   quoted=single ;;
            '>')          op='-gt'  quoted=single ;;
            '>=')         op='-ge'  quoted=single ;;
            '<')          op='-lt'  quoted=single ;;
            '<=')         op='-le'  quoted=single ;;
            'match')      op='=~'   quoted=double ;;
            'and'|'&&')   op='&&' ;;
            'or'|'||')    op='||' ;;
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
noshadow bash:compile 1
