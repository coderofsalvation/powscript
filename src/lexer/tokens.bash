declare -gA Tokens

Tokens[index]=0
Tokens[length]=0

TokenMark=0

store_token() {
  local idvar="$8"
  local index="${Tokens[length]}"

  Tokens[value-$index]="$1"
  Tokens[class-$index]="$2"
  Tokens[glued-$index]="$3"
  Tokens[linenumber_start-$index]="$4"
  Tokens[linenumber_end-$index]="$5"
  Tokens[collumn_start-$index]="$6"
  Tokens[collumn_end-$index]="$7"
  Tokens[index]=$(($index+1))
  Tokens[length]=$(($index+1))

  setvar "$idvar" $index
}
noshadow store_token 7

from_token() {
  setvar "$3" "${Tokens[${2}-${1}]}"
}

all_from_token() {
  local __token="$1"
  shift

  for var in "$@"; do
    from_token "$__token" "$var" "$var"
  done
}

get_selected_token() {
  setvar "$1" $((${Tokens[index]}))
}

clear_tokens() {
  Tokens[length]=$((${Tokens[index]}-$1))
  if [ ${Tokens[index]} -gt ${Tokens[length]} ]; then
    Tokens[index]=${Tokens[length]}
  fi
}

clear_all_tokens() {
  unset Tokens
  declare -gA Tokens
  Tokens[index]=0
  Tokens[length]=0
}

move_back_token_index() {
  Tokens[index]=$((${Tokens[index]}-1))
}

forward_token() {
  Tokens[index]=$((${Tokens[index]}+1))
}

in_topmost_token() {
  [ ${Tokens[index]} = ${Tokens[length]} ]
}


mark_token_position() {
  TokenMark=${Tokens[index]}
}

return_token_to_mark() {
  Tokens[index]=$TokenMark
}


find_token_by() {
  local field="$1"
  local value="$2"
  local token="${Tokens[index]}"
  local tokenvar="$3"
  local tvalue

  while [ $token -ge 0 ]; do
    from_token $token $field tvalue
    if [[ "$tvalue" =~ ^$value$ ]]; then
      setvar "$tokenvar" $token
      return
    else
      token=$(($token-1))
    fi
  done
  setvar "$tokenvar" '-1'
}
noshadow find_token_by 2

