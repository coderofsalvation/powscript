
# setvar varname value
# dynamic variable assignation

setvar() {
  if [ -n "$1" ]; then
    printf -v "$1" '%s' "$2"
  else
    echo "$2"
  fi
}

