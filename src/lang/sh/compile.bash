powscript_source lang/sh/interactive.bash #<<EXPAND>>

sh:run() {
  sh -c "$1"
}

sh:compile() { #<<NOSHADOW>>
  local expr="$1" out="$2"
  local expr_head

  ast:from $expr head expr_head

  set_substitution() {
    if ${NO_QUOTING-false}; then
      setvar "$out" "$1"
    else
      setvar "$out" "\"$1\""
    fi
  }


  case "$expr_head" in
    name)
      ast:from $expr value "$out"
      ;;

    string)
      local string
      ast:from $expr value string
      if [ "$string" = "'" ]; then
        setvar "$out" "\"'\""
      else
        setvar "$out" "'$string'"
      fi
      ;;

    double-string)
      local string
      ast:from $expr value string
      setvar "$out" "\"$string\""
      ;;

    cat)
      local child compiled result=""
      ast:from $expr children expr_children
      for child in $expr_children; do
        backend:compile $child compiled
        result="$result$compiled"
      done
      setvar "$out" "$result"
      ;;

    require)
      local file_ast file code compiled_file
      ast:from $expr children file_ast

      bash:compile $file_ast file
      file="$(eval "echo $file")"

      case "$file" in
        /*) ;;
        *)  file="${POWCOMP_DIR-$PWD}/$file" ;;
      esac

      code="$(cat "$file")"$'\n\n'
      compiled_file="$(POWCOMP_DIR="$(dirname "$file")" files:compile-file <<<"$code")"

      setvar "$out" "$compiled_file"$'\n'
      ;;

    assert)
      local condition_ast message_ast condition message
      local NL=$'\n'

      ast:children $expr condition_ast message_ast

      backend:compile $condition_ast condition

      if ast:is $message_ast print_condition; then
        message="Assertation failed: $(ast:print $condition_ast)"
      else
        backend:compile $message_ast message
      fi
      message="<<'ASSERT_EOF'$NL$message${NL}ASSERT_EOF$NL"

      setvar "$out" "if $condition; then :; else >&2 cat $message$NL exit 1; fi"
      ;;

    and|pipe|file-input)
      local left_ast right_ast
      local left right op

      ast:children $expr left_ast right_ast

      backend:compile $left_ast  left
      backend:compile $right_ast right

      case "$expr_head" in
        and)        op='&' ;;
        pipe)       op='|' ;;
        file-input) op='<' ;;
      esac

      setvar "$out" "$left $op $right"
      ;;

    assign)
      local var_ast value_ast
      local var value

      ast:children $expr var_ast value_ast

      backend:compile $var_ast   var
      backend:compile $value_ast value

      setvar "$out" "$var=$value"
      ;;

    assign-sequence)
      local assign_ast expr_children
      local result="" assign

      ast:from $expr children expr_children

      for assign_ast in $expr_children; do
        backend:compile $assign_ast assign
        result+="$assign "
      done
      setvar "$out" "$result"
      ;;

    readline)
      local var_ast
      local var

      ast:children $expr var_ast

      backend:compile $var_ast var

      setvar "$out" "IFS= read $var || [ -n \"\$$var\" ]"
      ;;
    math-assigned)
      local value_ast value

      ast:from $expr children value_ast

      NO_QUOTING=true backend:compile $value_ast value

      setvar "$out" "\$(( $value ))"
      ;;

    concat-assign)
      local var_ast value_ast
      local var value

      ast:children $expr var_ast value_ast

      backend:compile $var_ast   var
      backend:compile $value_ast value

      setvar "$out" "$var=\"\${$var}\"$value"
      ;;

    call)
      local children arg_ast
      local result assigns cmd arg

      ast:from $expr children children
      children=( $children )

      backend:compile ${children[0]} assigns
      backend:compile ${children[1]} cmd

      result="$assigns$cmd"
      for arg_ast in "${children[@]:2}"; do
        backend:compile $arg_ast arg
        result="$result $arg"
      done
      setvar "$out" "$result"
      ;;

    empty-substitution)
      set_substitution "\${NOTHING:+}"
      ;;

    command-substitution)
      local call_ast call

      ast:from $expr children call_ast

      backend:compile $call_ast call

      if ast:is $call_ast math-top; then
        setvar "$out" "${call:5}"
      else
        set_substitution "\$( $call )"
      fi
      ;;

    if|elif)
      local condition block after
      backend:compile-children $expr condition block after

      setvar "$out" "$expr_head $condition; then"$'\n'"${block:2:-2}"$'\n'"$after"
      ;;

    else)
      local block
      backend:compile-children $expr block

      setvar "$out" "else"$'\n'"${block:2:-2}"$'\n'"fi"
      ;;

    end_if)
      setvar "$out" "fi"
      ;;

    for)
      local varname loc=''
      local elements block

      backend:compile-children $expr varname elements block

      ${INSIDE_FUNCTION-false} && loc="local $varname; "

      setvar "$out" "${loc}for $varname in $elements; do"$'\n'"${block:2:-2}"$'\ndone'
      ;;

    while)
      local condition block
      backend:compile-children $expr condition block

      setvar "$out" "while $condition; do"$'\n'"${block:2:-2}"$'\ndone'
      ;;
    switch)
      local value cases
      backend:compile-children $expr value cases

      setvar "$out" "case $value in"$'\n'"${cases:2:-2}"$'\n'"esac"
      ;;

    case)
      local pattern block
      backend:compile-children $expr pattern block

      setvar "$out" "$pattern)"$'\n'"${block:2:-2}"$'\n;;'
      ;;

    elements)
      local e elements r result

      ast:from $expr children elements

      for e in $elements; do
        backend:compile $e r
        result="$result$r "
      done

      setvar "$out" "${result:0:-1}"
      ;;

    simple-substitution)
      local name
      ast:from $expr value name
      set_substitution "\${$name}"
      ;;

    string-length)
      local name
      ast:from $expr value name
      set_substitution "\${#$name}"
      ;;

    string-indirect)
      local name
      ast:from $expr value name
      set_substitution "\${!$name}"
      ;;

    string-removal)
      local name pattern_ast op_ast
      local pattern op

      ast:from $expr value name
      ast:children $expr pattern_ast op_ast

      backend:compile $pattern_ast pattern
      backend:compile $op_ast op

      set_substitution "\${$name$op$pattern}"
      ;;

    string-default)
      local name default_ast op_ast
      local default op

      ast:from $expr value name
      ast:children $expr default_ast op_ast

      backend:compile $default_ast default
      backend:compile $op_ast op

      set_substitution "\${$name$op$default}"
      ;;

    math-float)
      local precision child_ast child

      ast:from $expr value precision
      ast:from $expr children child_ast
      NO_QUOTING=true FLOAT_MATH=true backend:compile $child_ast child

      setvar "$out" "echo \"{scale=$precision; $child}\" | bc"
      ;;
    math-top)
      local child_ast child

      ast:from $expr children child_ast
      NO_QUOTING=true backend:compile $child_ast child

      setvar "$out" "echo \$(( $child ))"
      ;;

    math)
      local left_ast right_ast op
      local left right

      ast:all-from $expr -v op -@ left_ast right_ast

      if [ "$op" = "^" ] && ! ${FLOAT_MATH-false}; then
        case $PowscriptBackend in
          sh)
            backend:error "unimplemented: ^ operator in math"
            return
            ;;
          bash)
            op="**"
            ;;
        esac
      fi

      backend:compile $left_ast left

      if [ -n "$right_ast" ]; then
        backend:compile $right_ast right
        setvar "$out" "$left$op$right"
      else
        setvar "$out" "$op$left"
      fi
      ;;

    function-def)
      local name_ast args_ast block_ast
      local name block

      ast:children $expr name_ast args_ast block_ast

      backend:compile $name_ast name
      INSIDE_FUNCTION=true backend:compile $block_ast block

      setvar "$out" "$name() $block"
      ;;

    local)
      local result child_ast child
      ast:from $expr children expr_children

      if ${INSIDE_FUNCTION-false}; then
        result="local"
      else
        result=":"
      fi

      for child_ast in $expr_children; do
        sh:compile $child_ast child
        if ${INSIDE_FUNCTION-false}; then
          result+=" $child"
        else
          result+="; $child"
        fi
      done

      setvar "$out" "$result"
      ;;

    declare)
      local result
      ast:set $expr head local
      sh:compile $expr result
      ast:set $expr head declare

      setvar "$out" "$result"
      ;;

    block)
      local child_ast child result
      ast:from $expr children expr_children

      result='{'
      for child_ast in $expr_children; do
        backend:compile $child_ast child
        result="$result"$'\n'"$child"
      done
      result="$result"$'\n}'

      setvar "$out" "$result"
      ;;

    pattern)
      ast:from $expr value "$out"
      ;;

    condition)
      local op left right quoted=no
      ast:from $expr value op
      ast:from $expr children expr_children
      expr_children=( $expr_children )

      case "$op" in
        command)
          sh:compile ${expr_children[0]} left
          setvar "$out" "$left"
          ;;
        not)
          sh:compile ${expr_children[0]} right
          setvar "$out" "! $right"
          ;;
        -*)
          bash:compile ${expr_children[0]} right
          setvar "$out" "[ $op $right ]"
          ;;
        *)
          sh:compile ${expr_children[0]} left
          sh:compile ${expr_children[1]} right

          case "$op" in
            'is'|'=')     op='='    quoted=single ;;
            'isnt'|'!=')  op='!='   quoted=single ;;
            '==')         op='-eq'  quoted=single ;;
            '>')          op='-gt'  quoted=single ;;
            '>=')         op='-ge'  quoted=single ;;
            '<')          op='-lt'  quoted=single ;;
            '<=')         op='-le'  quoted=single ;;
            'and'|'&&')   op='&&' ;;
            'or'|'||')    op='||' ;;
            *) backend:error "unimplemented: condition: $op" ;;
          esac

          case $quoted in
            single) setvar "$out"  "[ $left $op $right ]"  ;;
            no)     setvar "$out"    "$left $op $right"    ;;
          esac
          ;;
      esac
      ;;
    expand)
      local block_ast block quoted_block
      ast:from $expr children block_ast
      backend:compile $block_ast block

      setvar quoted_block "${block//\\/\\\\}"
      setvar quoted_block "${block//\"/\\\"}"
      setvar quoted_block "${quoted_block//\$/\\\$}"
      setvar quoted_block "${quoted_block//\~/\$}"
      setvar "$out" "eval \"$quoted_block\""
      ;;
    newline|eof|'')
      ;;
    *)
      backend:error "unimplemented: '$expr_head'"
      ;;
  esac
}
noshadow sh:compile 1
