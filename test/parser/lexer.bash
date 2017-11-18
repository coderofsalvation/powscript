#!/bin/bash

source "$PWD/src/powscript.bash" -d

test_tokens() {
  local value  class  glued
  local tvalue tclass tglued
  local ignore_til_match unmatched

  local tests=(
    '"echo"           name         true'
    '"hello world"    string       false'
    '""               newline      false'
    '-"f"             name         true'
    '"("              special      true'
    '")"              special      true'
    '"{"              special      false'
    '""               newline      false'
    '"2"              whitespace   true'
    '"printf"         name         true'
    '"-v"             name         false'
    '"x"              name         false'
    '"x: "            string       false'
    '"$"              special      true'
    '"1"              name         true'
    '""               string       true'
    '-"if"            name         true'
    '"$"              special      false'
    '"x"              name         true'
    '-"4"             whitespace   true'
    '"echo"           name         true'
    '"10"             name         false'
    '-"}"             special      true'
    '-"("             special      true'
    '-"1"             whitespace   true'
    '"echo"           name         true'
    $'"a\n b\n c\n "  string       false'
    '-")"             special      true'
    '-"x"             name         true'
    '"["              special      true'
    '"y"              name         true'
    '"]"              special      true'
    '"="              special      true'
    '"10"             name         true'
    '-"eof"           eof          false'
  )

  stream:init

  echo 'testing lexer...'
  for t in "${tests[@]}"; do
    if [ "${t:0:1}" = "-" ]; then
      ignore_til_match=true
    else
      ignore_til_match=false
    fi

    tvalue="${t#*\"}"
    tvalue="${tvalue%\"*}"

    tglued="${t##* }"

    tclass="${t##*\"}"
    tclass="${tclass%%$tglued}"
    tclass="${tclass// /}"

    unmatched=true
    while $unmatched && ! stream:end; do
      token:get -v value -c class -g glued

      if [ "$value" = "$tvalue" ] &&
         [ "$class" = "$tclass" ] &&
         [ "$glued" = "$tglued" ]; then
        unmatched=false
      elif ! $ignore_til_match || stream:end; then
        >&2 echo "failed test while testing lexer!"
        >&2 echo "  tried to match {value: '$tvalue', class: '$tclass', glued: $tglued }"
        >&2 echo "  instead found  {value: '$value', class: '$class', glued: $glued }"
        exit 1
      fi
    done
  done
  echo success!
}



test_tokens < 'test/test-files/parse-me.pow'
