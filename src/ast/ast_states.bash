declare -gA AstStates

AstStates[index]=0
AstStates[0]=top

ast_push_state() {
  local index=$((${AstStates[index]}+1))

  AstStates[index]=$index
  AstStates[$index]=$1
}

ast_pop_state() {
  AstStates[index]=$((${AstStates[index]}-1))
}

ast_last_state() {
  setvar "$1" "${AstStates[${AstStates[index]}]}"
}

ast_state_is() {
  local state
  ast_last_state state
  [ "$state" = "$1" ]
}

ast_clear_states() {
  unset AstStates
  declare -gA AstStates
  AstStates[index]=0
  AstStates[0]=top
}
