powscript_source lang/bash/interactive.bash #<<EXPAND>>

bash:compile() { #<<NOSHADOW>>
  local expr=$1 out="$2"
  local expr_head expr_value expr_children

  ast:from $expr head expr_head

  case "$expr_head" in
    name|string|assign|cat|if|elif|else|end_if|call|for|command-substitution|switch|case)
      sh:compile $expr "$out"
      ;;

    elements|simple-substitution|function-def|local|block|math|math-top|math-assigned)
      sh:compile $expr "$out"
      ;;

    indexing-substitution)
      local name index expr_children

      ast:from $expr children expr_children
      expr_children=( $expr_children )

      ast:from $expr value name
      bash:compile ${expr_children[0]} index

      setvar "$out" "\"\${$name[$index]}\""
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

    list-assign)
      local name_ast list_ast name list

      ast:children $expr name_ast list_ast

      sh:compile   $name_ast name
      bash:compile $list_ast list

      setvar "$out" "$name=$list"
      ;;

    associative-assign)
      local name_ast name value_ast value_children

      ast:children $expr name_ast value_ast
      ast:from $value_ast children value_children

      sh:compile $name_ast name

      if [ -n "$value_children" ]; then
        >&2 echo "warning: Associative arrays with elements aren't implemented yet. Ignoring elements."
      fi
      setvar "$out" "declare -A $name"
      ;;

    array-length)
      local name
      ast:from $expr value name

      setvar "$out" "\${#$name[@]}"
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
        -*)
          bash:compile ${expr_children[0]} right
          setvar "$out" "[ $op $right ]"
          ;;
        *)
          bash:compile ${expr_children[0]} left
          bash:compile ${expr_children[1]} right

          case "$op" in
            'is'|'=')     op='='    quoted=single ;;
            'isnt'|'!=')  op='!='   quoted=single ;;
            '==')         op='-eq'  quoted=single ;;
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
    newline|eof|'')
      ;;
    *)
      backend:error "unimplemented: '$expr_head'"
      ;;
  esac
}
noshadow bash:compile 1
