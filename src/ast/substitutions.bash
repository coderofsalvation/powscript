# ast:parse:substitution $out
#
# Parse expressions of the form $variable or $array[index]
#

ast:parse:substitution() { #<<NOSHADOW>>
  local subst curly="$1" out="$2"
  local expr value head varname aftervar
  local index lb rb aft
  local postcat
  local cat_children cat_array dollar

  ast:parse:expr expr
  ast:all-from "$expr" -v value -h head -@ varname aftervar

  case "$head" in
    name)
      if ast:state-is '{' && ! token:next-is special '}'; then
        if token:next-is special ':'; then
          token:require special ':'
          ast:make postcat cat ''
          ast:parse:parameter-substitution $postcat "$value" subst
        elif [ "$value" = "@:" ]; then
          ast:make postcat cat ''
          ast:parse:parameter-substitution $postcat "@" subst
        else
          local sym class
          token:peek -v sym -c class
          ast:error "unimplemented variable substitution (found $sym::$class instead of [ or :)"
        fi
      else
        ast:make subst simple-substitution "$value"
      fi
      ;;
    cat)
      if ast:is $varname name; then
        if ast:is $aftervar name '['; then
          ast:children "$expr" varname lb index rb aft
          ast:from $varname value value
          ast:make subst indexing-substitution "$value" $index

          if [ -n "$aft" ]; then
            if ${AST_MATH_MODE-false}; then
              ast:error "invalid math expression: $(ast:print $expr)"

            elif $curly; then
              if ast:is $aft name ':'; then
                local param
                ast:from $expr children cat_children
                cat_array=( $cat_children )
                ast:make postcat cat '' "${cat_array[@]:5}"
                ast:parse:parameter-substitution $postcat "@" param

                if ast:is $param indirect-indexing-substitution; then
                  ast:error "unimplemented variable substitution (keys used after indexing)"
                else
                  ast:make subst array-operation '' $subst $param
                fi

              else
                ast:error "unimplemented variable substitution (found $(ast:print $aft) while looking for } or :)"
              fi

            else
              ast:from $expr children cat_children
              cat_array=( $cat_children )
              ast:make subst cat '' $subst "${cat_array[@]:4}"
            fi
          elif token:next-is special ':'; then
            local param
            token:skip
            ast:make postcat cat ''
            ast:parse:parameter-substitution $postcat "@" param

            if ast:is $param indirect-indexing-substitution; then
              ast:error "unimplemented variable substitution (keys used after indexing)"
            else
              ast:make subst array-operation '' $subst $param
            fi

          fi
        elif $curly; then
           ast:from $expr children cat_children
           cat_array=( $cat_children )

          if ast:is $aftervar name ':'; then
            ast:make postcat cat '' "${cat_array[@]:2}"
            ast:from $varname value value
            ast:parse:parameter-substitution $postcat "$value" subst

          elif ast:is $varname name "@:"; then
            ast:make postcat cat '' "${cat_array[@]:1}"
            ast:parse:parameter-substitution $postcat "@" subst

          else
            ast:error "unimplemented variable substitution ($(ast:print $varname) directly followed by $(ast:print $aftervar) instead of : or [)"
          fi
        else
          ast:set $varname head simple-substitution
          subst=$expr
        fi
      else
        ast:make dollar name '$'
        ast:unshift-child $expr $dollar
        subst=$expr
      fi
      ;;
    *)
      ast:error "unimplemented variable substitution (not a name nor a cat)"
      ;;
  esac
  setvar "$out" $subst
}
noshadow ast:parse:substitution 1


# ast:parse:curly-substitution
#
# Parse expressions of the form ${}, ${variable} or ${array[index]}
#

ast:parse:curly-substitution() { #<<NOSHADOW>>
  local out="$1"
  local subst

  if token:next-is special '}'; then
    ast:make subst empty-substitution ''
  else
    ast:push-state '{'
    ast:parse:substitution true subst
    ast:pop-state
  fi

  token:require special '}'
  setvar "$out" $subst
}
noshadow ast:parse:curly-substitution

# ast:parse:parameter-substitution $postcat $varname $out
#
# Parse string substitution commands, of the form:
#
# unset <expr>
# unset= <expr>
# empty <expr>
# empty= <expr>
# set <expr>
# set! <expr>
# nonempty <expr>
# nonempty! <expr>
# length
# index <math expression>
# from <math expression> to <math expression>
# slice <math expression> length <math expression>
# suffix <pattern>
# prefix <pattern>
# suffix* <pattern>
# prefix* <pattern>
# replace <pattern> by <expr>
# replace* <pattern> by <expr>
# uppercase <pattern>
# lowercase <pattern>
# uppercase* <pattern>
# lowercase* <pattern>
# indirect
# keys
#

ast:parse:parameter-substitution() { #<<NOSHADOW>>
  local postcat="$1" varname="$2" out="$3"
  local child_a child_b child_c
  local opname opclass postname postclass
  local modifier mclass
  local glued

  ast:children $postcat child_a child_b child_c
  if [ -z "$child_a" ]; then
    token:get -v opname -c opclass
    [ $opclass = 'name' ] || ast:error "Invalid string operation: $opname::$opclass"
  elif ast:is $child_a name; then
    ast:from $child_a value opname
  else
    ast:error "Expected a name for a string operation, got: $(ast:print $child_b)"
  fi

  case "$opname" in
    unset|empty)   modifier='='; mclass='string' ;;
    set|nonempty)  modifier='!'; mclass='name'   ;;
    *fix|replace)  modifier='*'  mclass='name'   ;;
    *case)         modifier='*'  mclass='name'   ;;
  esac


  case "$opname" in
    unset|empty|*fix|*case|replace)
      if [ -n "$child_b" ]; then
        if ast:is $child_b "$mclass" "$modifier"; then
          opname="$opname$modifier"
        else
          ast:error "trailling expression after operation name: $(ast:print $child_b)"
        fi
      else
        if token:next-is special "$modifier"; then
          token:peek -g glued
          if $glued; then
            opname="$opname$modifier"
            token:skip
          fi
        else
          token:peek -v postname -g glued
          if $glued && ! token:next-is special '}'; then
            ast:error "Invalid string operation: $opname$postname"
          fi
        fi
      fi
      ;;

    *)
      if [ -n "$child_b" ]; then
        ast:error "trailling expression after operation name: $(ast:print $child_b)"
      else
        token:peek -v postname -g glued
        if $glued && ! token:next-is special '}'; then
          ast:error "Invalid string operation: $opname$postname"
        fi
      fi
      ;;
  esac

  case "$opname" in
    length|indirect)
      ast:make "$out" "string-$opname" "$varname"
      ;;
    keys)
      local at
      ast:make at name '@'
      ast:make "$out" indirect-indexing-substitution "$varname" $at
      ;;
    slice)
      local start len
      NOBC=true ast:parse:math start
      token:require name length
      NOBC=true ast:parse:math len
      ast:make "$out" string-slice "$varname" $start $len
      ;;
    from)
      local from to
      NOBC=true ast:parse:math from
      token:require name to
      NOBC=true ast:parse:math to
      ast:make "$out" string-from "$varname" $from $to
      ;;
    index)
      local index
      NOBC=true ast:parse:math index
      ast:make "$out" string-index "$varname" $index
      ;;
    *fix*|*case*)
      local pattern op opval optype
      case "$opname" in
        suffix)      opval='%'  optype='removal';;
        prefix)      opval='#'  optype='removal';;
        suffix\*)    opval='%%' optype='removal';;
        prefix\*)    opval='##' optype='removal';;
        lowercase)   opval=','  optype='case'   ;;
        uppercase)   opval='^'  optype='case'   ;;
        lowercase\*) opval=',,' optype='case'   ;;
        uppercase\*) opval='^^' optype='case'   ;;
        *)
          ast:error "Invalid string operation: $opname"
          ;;
      esac
      ast:make op name "$opval"
      ast:parse:pattern 'string-op' pattern
      ast:make "$out" "string-$optype" "$varname" $pattern $op
      ;;
    replace*)
      local pattern by op opval
      case "$opname" in
        replace)   opval='/'  ;;
        replace\*) opval='//' ;;
        *)
          ast:error "Invalid string operation: $opname"
          ;;
      esac
      ast:make op name "$opval"
      ast:parse:pattern 'replace' pattern
      token:require name by
      ast:parse:pattern 'string-op' by
      ast:make "$out" string-replace "$varname" $pattern $by $op
      ;;
    unset*|empty*|set*|nonempty*)
      local expr op opval
      case "$opname" in
        unset)     opval='-'  ;;
        unset=)    opval='='  ;;
        empty)     opval=':-' ;;
        empty=)    opval=':=' ;;
        set)       opval='+'  ;;
        nonempty)  opval=':+' ;;
        set!)      opval='?'  ;;
        nonempty!) opval=':?' ;;
        *)
          ast:error "Invalid string operation: $opname"
          ;;
      esac
      ast:make op name "$opval"
      if [ -n "$child_c" ]; then
        expr=$child_c
      else
        ast:parse:expr expr
      fi
      ast:to-double-string $expr
      ast:make "$out" string-default "$varname" $expr $op
      ;;

    *)
      ast:error "Invalid string operation: $opname"
      ;;
  esac

}
noshadow ast:parse:parameter-substitution 2

# ast:parse:command-substitution
#
# Parse expressions of the form $(command ...) or $(math <math expression>)
#

ast:parse:command-substitution() { #<<NOSHADOW>>
  local out="$1"
  local subst cmd call assigns

  ast:push-state '('
  ast:parse:command-call '' call
  ast:pop-state

  ast:make subst command-substitution '' $call
  setvar "$out" $subst
}
noshadow ast:parse:command-substitution

