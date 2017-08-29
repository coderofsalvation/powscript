declare -A Stream

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

end_of_file() {
  ${Stream[eof]}
}

line_start() {
  [ ${Stream[index]} = 0 ]
}

get_line_number() {
  setvar "$1" ${Stream[linenumber]}
}

get_collumn() {
  setvar "$1" ${Stream[index]}
}

