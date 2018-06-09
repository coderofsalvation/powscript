powscript_source lang/bash/interactive.bash #<<EXPAND>>

bash:run() {
  bash -c "$1"
}

bash:compile() { #<<NOSHADOW>>
  local expr=$1 out="$2"
  local expr_head expr_value expr_children

  ast:from $expr head expr_head

  set_substitution() {
    if ${NO_QUOTING-false}; then
      setvar "$out" "$1"
    else
      setvar "$out" "\"$1\""
    fi
  }

  case "$expr_head" in
    name|string|assign|cat|if|elif|else|end_if|call|for|\
    while|expand|command-substitution|switch|case|require|\
    pattern|and|pipe|elements|simple-substitution|*assert|\
    function-def|local|block|math|math-top|math-float|\
    math-assigned|math-expr|assign-sequence|readline|file-input|\
    string-length|string-removal|string-default|string-test|\
    string-indirect|double-string|nothing|empty-substitution|flag*)

      sh:compile $expr "$out"
      ;;

    declare)
      local result type child_ast child expr_children

      ast:from $expr value type
      ast:from $expr children expr_children

      case "$type" in
        integer) result="declare -i" ;;
        array)   result="declare -a" ;;
        map)     result="declare -A" ;;
        string)  result="declare" ;;
        'global integer') result="declare -gi" ;;
        'global array')   result="declare -ga" ;;
        'global map')     result="declare -gA" ;;
        'global string')  result="declare -g" ;;
      esac

      for child_ast in $expr_children; do
        bash:compile $child_ast child
        result+=" $child"
      done

      setvar "$out" "$result"
      ;;

    indexing-substitution)
      local name index expr_children

      ast:from $expr children expr_children
      expr_children=( $expr_children )

      ast:from $expr value name
      bash:compile ${expr_children[0]} index

      setvar "$out" "\"\${$name[$index]}\""
      ;;

    indirect-indexing-substitution)
      local name expr_children

      ast:from $expr children expr_children
      expr_children=( $expr_children )

      ast:from $expr value name
      bash:compile ${expr_children[0]} index

      setvar "$out" "\"\${!$name[$index]}\""
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

    add-assign)
      local name_ast value_ast name value

      ast:children $expr name_ast value_ast

      bash:compile $name_ast  name
      bash:compile $value_ast value

      setvar "$out" "$name+=$value"
      ;;

    associative-assign)
      local name_ast name value_ast value_children

      ast:children $expr name_ast value_ast
      ast:from $value_ast children value_children

      backend:compile $name_ast name

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

    concat-assign)
      local name_ast value_ast
      local name value

      ast:children $expr name_ast value_ast

      backend:compile $name_ast  name
      backend:compile $value_ast value

      setvar "$out" "$name=\"\${$name}\"$value"
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

    string-index)
      local name index_ast
      local index

      ast:from $expr value name
      ast:children $expr index_ast

      backend:compile $index_ast index

      set_substitution "\${$name:$index:1}"
      ;;

    string-slice-from)
      local name start_ast
      local start

      ast:from $expr value name
      ast:children $expr start_ast

      backend:compile $start_ast start

      set_substitution "\${$name:$start}"
      ;;

    string-slice)
      local name start_ast len_ast
      local start len

      ast:from $expr value name
      ast:children $expr start_ast len_ast

      backend:compile $start_ast start
      backend:compile $len_ast   len

      set_substitution "\${$name:$start:$len}"
      ;;

    string-from)
      local name from_ast to_ast
      local from to from_cond to_cond len

      ast:from $expr value name
      ast:children $expr from_ast to_ast

      backend:compile $from_ast from
      backend:compile $to_ast   to

      from="${from#\$(( }"
      from="${from% ))}"

      to="${to#\$(( }"
      to="${to% ))}"

      from="\$(($from < 0 ? 0 : $from))"
      to="\$(($to < 0 ? -1 : $to))"
      len="\$(($to < $from ? 0 : $to-$from+1))"

      set_substitution "\${$name:$from:$len}"
      ;;

    string-case)
      local name pattern_ast op_ast
      local pattern op

      ast:from $expr value name
      ast:children $expr pattern_ast op_ast

      backend:compile $pattern_ast pattern
      backend:compile $op_ast op

      set_substitution "\${$name$op$pattern}"
      ;;

    string-replace)
      local name pattern_ast by_ast op_ast
      local pattern by op

      ast:from $expr value name
      ast:children $expr pattern_ast by_ast op_ast

      backend:compile $pattern_ast pattern
      backend:compile $by_ast      by
      backend:compile $op_ast      op

      pattern="${pattern//\//\\\/}"
      by="${by//\//\\\/}"

      pattern="${pattern% }"

      set_substitution "\${$name$op$pattern/$by}"
      ;;

    array-operation|array-test)
      local subst_ast param_ast
      local subst param

      ast:children $expr subst_ast param_ast

      backend:compile $subst_ast subst
      backend:compile $param_ast param

      subst="${subst#\"}"
      subst="${subst#\$\{}"
      subst="${subst%\"}"
      subst="${subst%\}}"

      setvar "$out" "${param/@/$subst}"
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
