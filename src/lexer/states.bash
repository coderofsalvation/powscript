declare -gA States

States[index]=0

token:push-state() {
  States[${States[index]}]=$1
  States[index]=$((${States[index]}+1))
}

token:pop-state() {
  local index=$((${States[index]}-1))
  States[index]=$index
  setvar "$1" ${States[$index]}
}

token:in-topmost-state() {
  [ ${States[index]} = 1 ]
}

token:clear-states() {
  unset States
  declare -gA States
  States[index]=0
  token:push-state top
}

token:push-state top
