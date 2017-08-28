declare -A Stream

Stream[line]=""
Stream[index]=0
Stream[linenumber]=0

get_character() {
  if [ ${Stream[index]} = ${#Stream[line]} ]; then
    printf '\n'
  else
    echo ${Stream[line]:${Stream[index]}:1}
  fi
}

next_character() {
  if [ ${Stream[index]} = ${Stream[line]} ]; then
    if IFS='' read line; then
      Stream[line]="$line"
      Stream[index]=0
      Stream[linenumber]=$((${Stream[linenumber]}+1))
    else
      echo "unexpected end of file!" 2>
      exit 1
    fi
  else
    Stream[index]=$((${Stream[index]}+1))
  fi
}

next_character

