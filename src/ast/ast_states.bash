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
