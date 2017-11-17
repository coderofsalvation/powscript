declare -gA Tokens

Tokens[index]=0
Tokens[length]=0

TokenMark=0

store_token() { #<<NOSHADOW>>
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
  local __token="${@:$#}"

  while [ $# -gt 1 ]; do
    case "$1" in
      '-v'|'--value')
        from_token $__token value "$2"
        shift 2
        ;;
      '-c'|'--class')
        from_token $__token class "$2"
        shift 2
        ;;
      '-ls'|'--line-start')
        from_token $__token linenumber_start "$2"
        shift 2
        ;;
      '-le'|'--line-end')
        from_token $__token linenumber_end "$2"
        shift 2
        ;;
      '-g'|'--glued')
        from_token $__token glued "$2"
        shift 2
        ;;
      '-cs'|'--glued')
        from_token $__token collumn_start "$2"
        shift 2
        ;;
      '-ce'|'--glued')
        from_token $__token collumn_end "$2"
        shift 2
        ;;
      '-i'|'--id')
        setvar "$2" $__token
        shift 2
        ;;
      *)
        parse_error "unexpected argument $1, expecting -(v|c|ls|le|cs|ce|g|i), on line %line"
        ;;
    esac
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


find_token_by() { #<<NOSHADOW>>
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

