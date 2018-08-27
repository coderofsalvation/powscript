declare -gA AstStates

AstStates[index]=0
AstStates[0]=top

ast:push-state() {
  local index=$((${AstStates[index]}+1))

  AstStates[index]=$index
  AstStates[$index]=$1
}

ast:pop-state() {
  AstStates[index]=$((${AstStates[index]}-1))
}

ast:last-state() {
  setvar "$1" "${AstStates[${AstStates[index]}]}"
}

ast:state-is() {
  local state
  ast:last-state state
  [ "$state" = "$1" ]
}

ast:clear-states() {
  unset AstStates
  declare -gA AstStates
  AstStates[index]=0
  AstStates[0]=top
}

ast:ends-state() {
  local expr="$1"
  local state expr_value

  ast:last-state state

  if ast:is $expr name; then
    ast:from $expr value expr_value

    case "$state $expr_value" in
      "( )"|"[ ]"|"{ }")
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  else
    return 1
  fi
}


