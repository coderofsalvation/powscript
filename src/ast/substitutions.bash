# ast:parse:substitution $out
#
# Parse expressions of the form $variable or $array[index]
#

ast:parse:substitution() { #<<NOSHADOW>>
  local subst out="$1"
  local expr value head varname index lb rb aft
  local cat_children cat_array dollar

  ast:parse:expr expr
  ast:all-from "$expr" -v value -h head -@ varname lb index rb aft

  case "$head" in
    name)
      ast:make subst simple-substitution "$value"
      ;;
    cat)
      if ast:is $varname name; then
        if ast:is $lb name '['; then
          ast:from $varname value value
          ast:make subst indexing-substitution "$value" $index
          if [ -n "$aft" ]; then
            if ${AST_MATH_MODE-false}; then
              ast:error "invalid math expression: $(ast:print $expr)"
            fi
            ast:from $expr children cat_children
            cat_array=( $cat_children )
            ast:make subst cat $subst "${cat_array[@:4]}"
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
      ast:error "unimplemented variable substitution"
      ;;
  esac
  setvar "$out" $subst
}
noshadow ast:parse:substitution


# ast:parse:curly-substitution
#
# Parse expressions of the form ${variable} or ${array[index]}
#

ast:parse:curly-substitution() { #<<NOSHADOW>>
  local out="$1"
  local subst

  ast:push-state '{'
  ast:parse:substitution subst
  token:require special '}'
  ast:pop-state

  setvar "$out" $subst
}
noshadow ast:parse:curly-substitution


# ast:parse:command-substitution
#
# Parse expressions of the form $(command ...) or $(math <math expression>)
#

ast:parse:command-substitution() { #<<NOSHADOW>>
  local out="$1"
  local cmd call

  ast:make "$out" command-substitution ''

  ast:push-state '('

  ast:parse:expr cmd
  if ast:is $cmd name math; then
    ast:parse:math call
    token:require special ')'
  else
    ast:parse:commandcall $cmd call
  fi
  ast:pop-state

  ast:push-child "${!out}" $call
}
noshadow ast:parse:command-substitution

