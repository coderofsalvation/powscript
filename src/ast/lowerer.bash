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
      local var array block lowblock
      local array_name at elements

      ast:children $expr var array block

      ast:lower-scanned $block lowblock

      if ! ast:is $array name; then
        ast:error "for-of expression expected an array's name, got a $(ast:from $array head)"
      fi
      ast:from $array value array_name

      ast:make at name '@'
      ast:make elements indexing-substitution "$array_name" $at

      ast:make result 'for' '' $var $elements $lowblock
      ;;
    for-of-map)
      local key val array block lowblock
      local array_name at elements
      local val_assign val_local val_get key_name key_subst
      local newblock block_value block_children

      ast:children $expr key val array block

      ast:lower-scanned $block lowblock

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
      ast:make val_local local '' $val_assign

      ast:all-from $lowblock -v block_value -c block_children
      ast:make newblock block "$block_value" $val_local $block_children

      ast:make result 'for' '' $key $elements $newblock
      ;;
    for-from)
      local var file block lowblock
      local while_block readline

      ast:children $expr var file block

      ast:lower-scanned $block lowblock

      ast:make readline 'readline' '' $var
      ast:make while_block 'while' '' $readline $lowblock
      ast:make result 'file-input' '' $while_block $file
      ;;
    await-then)
      local cmd then
      local set_async var t block
      local lowblock

      ast:children $expr cmd then

      ast:make var 'name' 'ASYNC'
      ast:make t   'name' '1'
      ast:make set_async 'assign' '' $var $t

      ast:make block 'block' '' $cmd $then
      ast:lower-scanned $block lowblock

      ast:make result 'and' '' $lowblock $set_async
      ;;
    await-pipe)
      local cmd then done_block
      local set_async var t block pipe
      local lowblock

      ast:children $expr cmd then done_block

      ast:make var 'name' 'ASYNC'
      ast:make t   'name' '1'
      ast:make set_async 'assign' '' $var $t

      ast:make pipe  'pipe'  '' $cmd  $then
      ast:make block 'block' '' $pipe $done_block
      ast:lower-scanned $block lowblock

      ast:make result 'and' '' $lowblock $set_async
      ;;
    await-for)
      local cmd var then done_block
      local set_async avar t block
      local while_block readline pipe
      local lowblock

      ast:children $expr cmd var then done_block

      ast:make avar 'name' 'ASYNC'
      ast:make t    'name' '1'
      ast:make set_async 'assign' '' $avar $t

      ast:make readline 'readline' '' $var

      ast:make while_block 'while' '' $readline $then

      ast:make pipe  'pipe'  '' $cmd  $while_block
      ast:make block 'block' '' $pipe $done_block
      ast:lower-scanned $block lowblock

      ast:make result 'and' '' $lowblock $set_async
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
      local name args args_extract block block_lowered

      typing:start-scope
      ast:children $expr name args block

      ast:extract-function-arguments $args args_extract

      ast:lower-scanned $block block_lowered
      ast:unshift-child $block_lowered $args_extract
      ast:make result function-def '' $name $args $block_lowered

      typing:end-scope
      ;;
    name|math*|string)
      result=$expr
      ;;
    assign-conditional)
      local assign_type var varname value
      local op def
      ast:from $expr value assign_type
      ast:children $expr var value

      ast:from $var value varname
      ast:conditional-exp-operators "$assign_type?" op def
      ast:make-from-string result "
        if
        - condition is
        -- string-test $varname
        --- name $op
        --- name $def
        -- name 0
        - block
        -- assign
        --+ $var
        --+ $value
        - end_if
      "
      ;;

    assign-ref)
      local var value varname
      local lowvalue

      ast:children $expr var value
      ast:lower-scanned $value lowvalue

      ast:from $var value varname
      ast:make-from-string result "
        block
        - light-assert
        -- condition not
        --- condition is
        ---- string-removal $varname
        ----- pattern __powscript_gensym_reference_variable_
        ----- name #
        ---- simple-substitution $varname
        -- cat
        --- string ERROR:
        --- simple-substitution $varname
        --- string  is not a reference
        - expand
        -- block
        --- assign
        ---- name ~$varname
        ---+ $lowvalue
      "
      ;;

    call)
      local assigns cmd arguments arg arg_head arg_value
      local low_assigns low_cmd low_arguments=""
      local ref_assigns="" ref_returns=""
      ast:children $expr assigns cmd
      ast:from $expr children arguments
      pop 2 arguments $arguments

      ast:lower-scanned $assigns low_assigns
      ast:lower-scanned $cmd     low_cmd

      for arg in $arguments; do
        ast:all-from $arg -v arg_value -h arg_head
        case "$arg_head" in
          variable-reference)
            local refassign refret refvar refname
            ast:gensym refvar reference
            ast:from $refvar value refname
            ast:make-from-string refassign "
              local
              + $refvar
            "
            ast:make-from-string refret "
              assign
              - name $arg_value
              - simple-substitution $refname
            "
            ref_assigns+=" $refassign"
            ref_returns+=" $refret"
            low_arguments+=" $refvar"
            ;;
          *)
            low_arguments+=" $arg"
            ;;
        esac
      done

      if [ -z "$ref_assigns" ]; then
        ast:make result call '' $low_assigns $low_cmd $low_arguments
      else
        ast:make-from-string result "
          block
          + $ref_assigns
          - call
          -+ $low_assigns $low_cmd $low_arguments
          + $ref_returns
        "
      fi
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

ast:extract-function-arguments() { #<<NOSHADOW>>
  local args_expr="$1" out="$2"
  local positionals="" keywords=""
  local arg args arg_head arg_value
  local kw=false has_rest_pos=false has_rest_kw=false
  local rest_keyword rest_positional
  declare -i positional_count keyword_count

  positional_count=0
  keyword_count=0

  ast:from $args_expr children args

  for arg in $args; do
    ast:from $arg head arg_head
    case "$arg_head" in
      name)
        if { $has_rest_pos && ! $kw; } || $has_rest_kw; then
          ast:error "'rest' argument must be the last of it's kind in the list ($arg_value)"

        elif $kw; then
          keyword_count+=1
          ast:from $arg value arg_value
          ast:make arg name $arg_value
          keywords+=" $arg"

        else
          positional_count+=1
          positionals+=" $arg"
        fi
        ;;

      cat)
        local first second more
        ast:children $arg first second more

        if ast:is $first name '@' && ast:is $second name && [ -z "$more" ]; then
          ast:from $second value arg_value

          if { $has_rest_pos && ! $kw; } || $has_rest_kw; then
            ast:error "'rest' argument must be the last of it's kind in the list ($arg_value)"
          elif $kw; then
            has_rest_kw=true
            rest_keyword="$arg_value"
          else
            has_rest_pos=true
            rest_positional="$arg_value"
          fi
        else
          ast:error "Invalid name used for function argument (ast:print $arg)"
        fi
        ;;

      flag-double-dash-only)
        if $kw; then
          ast:error 'can only have one '--' in argument lists'
        else
          kw=true
        fi
        ;;
      *)
        ast:error "invalid function argument: $(ast:print $arg), $arg_head"
        ;;
    esac
  done

  case "$positional_count:$kw" in
    0:false)
      if $has_rest_pos; then
        ast:make-from-string "$out" "
        block
        - declare array
        -- name $rest_positional
        - assign
        -- name $rest_positional
        -- list
        --- simple-substitution @
        "
      else
        ast:make "$out" nothing
      fi
      ;;
    *:false)
      local locals test isset assign subst
      positional_count=1
      ast:make locals local '' $positionals
      ast:make "$out" block '' $locals
      if $has_rest_pos; then
        ast:make-from-string test "
          declare array
          - name $rest_positional
        "
        ast:push-child "${!out}" $test
      fi

      for arg in $positionals; do
        ast:make-from-string test "
          condition and
          - condition >=
          -- name \$#
          -- name $positional_count
          - assign
          -+ $arg
          -- simple-substitution $positional_count
        "
        ast:push-child "${!out}" $test
        positional_count+=1
      done
      if $has_rest_pos; then
        ast:make-from-string test "
          condition and
          - condition >=
          -- name \$#
          -- name $positional_count
          - assign
          -- name $rest_positional
          -- list
          --- string-slice-from @
          ---- name $positional_count
        "
        ast:push-child "${!out}" $test
      fi
      ;;
    *:true)
      local argvar keyvar posvar locals restdecs arg_set arg_test key_assign
      local key keyname keylocals="" keylocal

      ast:gensym argvar keyword_arg
      ast:gensym keyvar keyword_key
      ast:gensym posvar keyword_pos

      for key in $keywords; do
        ast:from $key value keyname
        ast:make keylocal name $keyname
        keylocals+=" $keylocal"
      done

      ast:make locals local '' $argvar $keyvar $posvar $positionals $keylocals

      ast:make-argument-test  "$argvar" "$keyvar" "$posvar" "$positionals" "$rest_positional" arg_test
      ast:make-keyword-assign "$argvar" "$keyvar" "$posvar" "$keywords"    "$rest_keyword"    key_assign
      ast:make-argument-set   "$argvar" "$keyvar" "$posvar" "$arg_test" "$key_assign" arg_set

      if $has_rest_pos || $has_rest_kw; then
        ast:make-from-string restdecs "
          block
          ${rest_positional:+"
            - declare array
            -- name $rest_positional
          "}
          ${rest_keyword:+"
            - declare map
            -- name $rest_keyword
          "}
        "
      fi
      ast:make "$out" block '' $locals $restdecs $arg_set
      ;;
  esac
}
noshadow ast:extract-function-arguments 1

RANDOM=$(date '+%s')
GENSYM_ID="$RANDOM"
declare -gi GensymCount=0
ast:gensym() {
  GensymCount+=1
  ast:make "$1" name "__powscript_gensym_${2}_variable_${GENSYM_ID}_${GensymCount}_$RANDOM"
}

ast:make-argument-set() { #<<NOSHADOW>>
  local argvar="$1" keyvar="$2" posvar="$3" arg_test="$4" key_assign="$5" out="$6"
  local keyvar_name

  ast:from $keyvar value keyvar_name

  ast:make-from-string "$out" "
    block
    - local
    -- assign
    --+ $posvar
    --- string 1
    - for
    -+ $argvar
    -- simple-substitution @
    -- block
    --- if
    ---- condition is
    ----- simple-substitution $keyvar_name
    ----- string
    ---- block
    ----+ $arg_test
    ---- else
    ----- block
    -----+ $key_assign
  "
}
noshadow ast:make-argument-set 5

ast:make-argument-test() { #<<NOSHADOW>>
  local argvar="$1" keyvar="$2" posvar="$3" positionals="$4" rpos="$5" out="$6"
  local arg argcase cases=""
  local argvar_name posvar_name emptycases
  declare -i poscount=1

  ast:from $argvar value argvar_name
  ast:from $posvar value posvar_name

  for arg in $positionals; do
    ast:make-from-string argcase "
      case
      - name $poscount
      - block
      -- assign
      --+ $arg
      --- simple-substitution $argvar_name
      -- assign
      --+ $posvar
      --- math-expr
      ---- math +
      ----+ $posvar
      ----- name 1
    "
    cases+=" $argcase"
    poscount+=1
  done

  if [ -n "$rpos" ]; then
    ast:make-from-string argcase "
      case
      - pattern *
      - block
      -- indexing-assign
      --- name $rpos
      --- array-length $rpos
      --- simple-substitution $argvar_name
      --+ $posvar
      --- math-expr
      ---- math +
      ----+ $posvar
      ----- name 1
    "
    cases+=" $argcase"
  fi

  if [ -z "$cases" ]; then
    emptycases="---- name true"
  fi

  ast:make-from-string "$out" "
    switch
    - simple-substitution $argvar_name
    - block
    -- case
    --- pattern -*
    --- block
    ---- assign
    ----+ $keyvar
    ----- simple-substitution $argvar_name
    -- case
    --- pattern *
    --- block
  ${cases:+"
    ---- switch
    ----- simple-substitution $posvar_name
    ----- block
    -----+ $cases
    "}
    $emptycases
  "
}
noshadow ast:make-argument-test 5

ast:make-keyword-assign() { #<<NOSHADOW>>
  local argvar="$1" keyvar="$2" posvar="$3" keywords="$4" rkey="$5" out="$6"
  local cases="" keycase key keyname keyshort
  local keyvar_name argvar_name

  ast:from $keyvar value keyvar_name
  ast:from $argvar value argvar_name

  for key in $keywords; do
    ast:from $key value keyname
    keyshort=${keyname:0:1}

    ast:make-from-string keycase "
      case
      - pattern --$keyname|-$keyshort
      - block
      -- assign
      --+ $key
      --- simple-substitution $argvar_name
    "
    cases+=" $keycase"
  done

  if [ -n "$rkey" ]; then
    ast:make-from-string keycase "
    case
    - pattern *
    - block
    -- assign
    --+ $keyvar
    --- string-slice-from $keyvar_name
    ---- name 1
    -- indexing-assign
    --- name $rkey
    --- string-removal $keyvar_name
    ---- pattern -
    ---- name #
    --- simple-substitution $argvar_name
    "
    cases+=" $keycase"
  else
    ast:make-from-string keycase "
    case
    - pattern *
    - block
    -- call
    --- assign-sequence
    --- name :
    "
    cases+=" $keycase"
  fi

  ast:make-from-string "$out" "
    block
    - switch
    -- simple-substitution $keyvar_name
    -- block
    --+ $cases
    - assign
    -+ $keyvar
    -- string
  "
}
noshadow ast:make-keyword-assign 5

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
    name|flag-double-dash-only|cat)
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
      type="${type#global }"

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

