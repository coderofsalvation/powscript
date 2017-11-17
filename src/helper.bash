# powscript_source
#
# include source relatively from the powscript source code directory

powscript_source() {
  source "$PowscriptSourceDirectory/$1"
}


# printf_seq $start $end $format
#
# calls printf on each element of $(seq $start $end)
# the specifier %N is used to reference the current number.

printf_seq() {
  local start="$1" end="$2" format="$3"
  for n in $(seq $start $end); do
    printf "${format//%N/$n}"
  done
}


# setvar $varname $value
#
# dynamic variable assignation

setvar() {
  if [ -n "$1" ]; then
    printf -v "$1" '%s' "$2"
  else
    echo "$2"
  fi
}

# noshadow name ${argnumber:-0} ${varnumber:-1}
#
# wrap the function so that the name of the out variables
# (assumed to be the last arguments) do not conflict
# with the local variables declared within the function.
#
# Passing @ instead of a number means the number of arguments
# is variable. You may have a argnumber or varnumber be @, but
# not both.

ClearShadowingCounter=0

noshadow() {
  local name="$1"
  local argnumber="${2:-0}"
  local varnumber="${3:-1}"
  local arguments set_variables intermediary_variables intermediary_definition
  local prefix="__noshadow_${ClearShadowingCounter}_"

  case $argnumber in
    '@')
      arguments="\"\${@:1:\$((\$# - $varnumber))}\""

      set_variables="shift \$((\$# - $varnumber))
        $(printf_seq 1 $varnumber\
          "setvar \"\$%N\" \"\$$prefix%N\"\n")"

      intermediary_variables="$(printf_seq 1 $varnumber "$prefix%N")"
      intermediary_definition="local $intermediary_variables"
      ;;
    *)
      arguments="$(printf_seq 1 $argnumber '"$%N" ')"

      case $varnumber in
        '@')
          local argshift="shift $((argnumber-1))"
          [ $argnumber = 0 ] && argshift=

          set_variables="#
          $argshift
          for ${prefix}n in \$(seq $((argnumber+1)) \$#); do
            setvar \"\$$((argnumber+1))\" \"\${!${prefix}all[\$${prefix}n]}\"
            shift
          done"

          intermediary_variables="\"\${${prefix}all[@]}\""
          intermediary_definition="declare -A ${prefix}all
          for ${prefix}n in \$(seq $((argnumber+1)) \$#); do
            ${prefix}all[\$${prefix}n]=${prefix}\$${prefix}n
          done"
          ;;
        *)
          set_variables="$(printf_seq $((argnumber+1)) $((varnumber+argnumber)) "setvar \"\$%N\" \"\$$prefix%N\"\n")"
          intermediary_variables="$(printf_seq $((argnumber+1)) $((varnumber+argnumber)) "$prefix%N ")"
          intermediary_definition="local $intermediary_variables"
          ;;
      esac
      ;;
  esac

  ${ShadowingOp-eval} "
__shadowing_$name() $(${ShadowingGetFunc-declare} -f $name | tail -n +2)

$name() {
  if [ -z \${$prefix+x} ]; then
    local $prefix
    $intermediary_definition
  fi
  __shadowing_$name $arguments $intermediary_variables
  $set_variables
}
"
  ClearShadowingCounter=$(($ClearShadowingCounter+1))
}

