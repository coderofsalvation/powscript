declare -gA Tokens

Tokens[index]=0
Tokens[length]=0

TokenMark=0

token:store() { #<<NOSHADOW>>
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
noshadow token:store 7

token:from() {
  setvar "$3" "${Tokens[${2}-${1}]}"
}

token:all-from() {
  local __token="${@:$#}"

  while [ $# -gt 1 ]; do
    case "$1" in
      '-v'|'--value')
        token:from $__token value "$2"
        shift 2
        ;;
      '-c'|'--class')
        token:from $__token class "$2"
        shift 2
        ;;
      '-ls'|'--line-start')
        token:from $__token linenumber_start "$2"
        shift 2
        ;;
      '-le'|'--line-end')
        token:from $__token linenumber_end "$2"
        shift 2
        ;;
      '-g'|'--glued')
        token:from $__token glued "$2"
        shift 2
        ;;
      '-cs'|'--collumn-start')
        token:from $__token collumn_start "$2"
        shift 2
        ;;
      '-ce'|'--collumn-end')
        token:from $__token collumn_end "$2"
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


token:get-selected() {
  setvar "$1" ${Tokens[index]}
}

token:clear() {
  Tokens[length]=$((${Tokens[index]}-$1))
  if [ ${Tokens[index]} -gt ${Tokens[length]} ]; then
    Tokens[index]=${Tokens[length]}
  fi
}

token:clear-all() {
  unset Tokens
  declare -gA Tokens
  Tokens[index]=0
  Tokens[length]=0
}

token:move-back-index() {
  Tokens[index]=$((${Tokens[index]}-1))
}

token:forward() {
  Tokens[index]=$((${Tokens[index]}+1))
}

token:in-topmost() {
  [ ${Tokens[index]} = ${Tokens[length]} ]
}


token:mark-position() {
  setvar "$1" ${Tokens[index]}
}

token:return-to-mark() {
  Tokens[index]="$1"
}


token:find-by() { #<<NOSHADOW>>
  local field="$1"
  local value="$2"
  local token="${Tokens[index]}"
  local tokenvar="$3"
  local tvalue

  while [ $token -ge 0 ]; do
    token:from $token $field tvalue
    if [[ "$tvalue" =~ ^$value$ ]]; then
      setvar "$tokenvar" $token
      return
    else
      token=$(($token-1))
    fi
  done
  setvar "$tokenvar" '-1'
}
noshadow token:find-by 2

