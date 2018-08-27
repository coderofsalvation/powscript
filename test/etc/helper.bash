#!/bin/bash

source "$PWD/src/helper.bash"

echo printf_seq

[ "$(printf_seq 1 10 '%N,')" = "1,2,3,4,5,6,7,8,9,10," ] || exit 1

echo setvar

setvar x 10
[ "$x" = 10 ] || exit 1

test_noshadow() {
  eval "
  (
    $1 $2 $(printf_seq 1 $3 'a%N ')
    $1 $2 $(printf_seq 1 $3 'x%N ')

    [ \"$(printf_seq 1 $3 '$a%N')\" = '$4' ] || return 1
    [ \"$(printf_seq 1 $3 '$x%N')\" = '' ]   || return 1

    [ -z \"\$(declare -f __$1)\" ] && noshadow $1 $5

    $1 $2 $(printf_seq 1 $3 'x%N ')

    [ \"$(printf_seq 1 $3 '$x%N')\" = '$4' ] || return 1
  ) || exit 1
  "
}

echo noshadow with only a name

cs_none() {
  local x1=10
  setvar $1 $x1
}
test_noshadow cs_none '' 1 '10' ''

echo noshadow with only the argument number

cs_an() {
  local x1=$1
  setvar "$2" $x1
}
test_noshadow cs_an '12' 1 '12' '1'

echo noshadow with numeric arguments

cs_an_vn() {
  local x1=$1 x2=$2

  setvar $3 $(($x1+$x2))
  setvar $4 $(($x1-$x2))
}
test_noshadow cs_an_vn '1 2' 2 '3-1' '2 2'

echo noshadow with a variable number of arguments

cs_avn() {
  local x1
  while [ $# -gt 1 ]; do
    x1="$x1,$1"
    shift
  done
  setvar "$1" "$x1"
}

test_noshadow cs_avn '1 2 3' 1 ',1,2,3' '@'
test_noshadow cs_avn 'a b'   1 ',a,b'   '@ 1'


echo noshadow with variable number of out variables

cs_vvn() {
  local x1=1 x2=2 x3=3
  for var in "$@"; do
    setvar $var "$(($x1+$x2+$x3))"
  done
}

test_noshadow cs_vvn '' 1 '6'   '0 @'
test_noshadow cs_vvn '' 2 '66'  '0 @'
test_noshadow cs_vvn '' 3 '666' '0 @'

echo 'success'
