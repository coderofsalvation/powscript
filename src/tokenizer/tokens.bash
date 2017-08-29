declare -A Tokens

Tokens[index]=0

store_token() {
  local __idvar="$8"
  local __index="${Tokens[index]}"

  Tokens[value-$__index]="$1"
  Tokens[class-$__index]="$2"
  Tokens[glued-$__index]="$3"
  Tokens[linenumber-start-$__index]="$4"
  Tokens[linenumber-end-$__index]="$5"
  Tokens[collumn-start-$__index]="$6"
  Tokens[collumn-end-$__index]="$7"
  Tokens[index]=$(($__index+1))

  setvar "$__idvar" $__index
}

from_token() {
  setvar "$3" "${Tokens[${2}-${1}]}"
}

get_last_token() {
  setvar "$1" ${Tokens[index]}
}

remove_last_token() {
  Tokens[index]=$((${Tokens[index]}-1))
}

find_token_by() {
  local __result
  __find_token_by "$1" "$2" __result
  setvar "$3" $__result
}

__find_token_by() {
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

