declare -gA Stream

stream:init() {
  Stream[line]=""
  Stream[index]=0
  Stream[linenumber]=0
  Stream[eof]=false

  stream:next-character
}

stream:get-character() {
  if stream:end; then
    (>&2 echo 'Tried to get an character after the end of file!')
    exit 1
  elif [ ${Stream[index]} = ${#Stream[line]} ]; then
    setvar "$1" $'\n'
  else
    setvar "$1" "${Stream[line]:${Stream[index]}:1}"
  fi
}

stream:next-character() {
  local line
  if [ ${Stream[index]} = ${#Stream[line]} ]; then
    if IFS='' read -r line || [ -n "$line" ]; then
      Stream[line]="$line"
      Stream[index]=0
      Stream[linenumber]=$((${Stream[linenumber]}+1))
    else
      Stream[eof]=true
    fi
  else
    Stream[index]=$((${Stream[index]}+1))
  fi
}

stream:require-string() {
  local req="$1" str="" c
  while [ ${#req} -gt ${#str} ]; do
    if stream:end; then
      >&2 echo "ERROR: end of input before the required string '$req' was found"
    fi
    stream:get-character c
    stream:next-character
    str+=$c
  done
  if [ "$str" = "$req" ]; then
    return 0
  else
    >&2 echo "ERROR:$(
      stream:get-line-number):$(
      stream:get-collumn):Found '$str' found instead of the required '$req'"
    return 1
  fi
}


stream:register-escaped-newline() {
  Stream[line]=" ${Stream[line]}"
  Stream[index]=$((${Stream[index]}+1))
}

stream:get-rest-of-line() { #<<NOSHADOW>>
  local line collumn out="$1"
  line="${Stream[line]}"
  stream:get-collumn collumn
  setvar "$out" "${line:$collumn}"
}
noshadow stream:get-rest-of-line


stream:end() {
  ${Stream[eof]}
}

stream:line-start() {
  [ ${Stream[index]} = 0 ]
}

stream:jump-to-collumn() {
  Stream[index]=$1
}

stream:get-line-number() {
  setvar "$1" ${Stream[linenumber]}
}

stream:get-collumn() {
  setvar "$1" ${Stream[index]}
}

