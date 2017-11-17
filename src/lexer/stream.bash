declare -gA Stream

init_stream() {
  Stream[line]=""
  Stream[index]=0
  Stream[linenumber]=0
  Stream[eof]=false

  next_character
}

get_character() {
  if end_of_file; then
    (>&2 echo 'Tried to get an character after the end of file!')
    exit 1
  elif [ ${Stream[index]} = ${#Stream[line]} ]; then
    setvar "$1" $'\n'
  else
    setvar "$1" "${Stream[line]:${Stream[index]}:1}"
  fi
}

next_character() {
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

get_rest_of_line() { #<<NOSHADOW>>
  local line collumn out="$1"
  line="${Stream[line]}"
  get_collumn collumn
  setvar "$out" "${line:$collumn}"
}
noshadow get_rest_of_line


end_of_file() {
  ${Stream[eof]}
}

line_start() {
  [ ${Stream[index]} = 0 ]
}

jump_to_collumn() {
  Stream[index]=$1
}

get_line_number() {
  setvar "$1" ${Stream[linenumber]}
}

get_collumn() {
  setvar "$1" ${Stream[index]}
}

