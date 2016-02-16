
#
# Nutshell functions
#

compose() {
  result_fun=$1; shift ; f1=$1; shift ; f2=$1; shift
  eval "$result_fun() { $f1 "$($f2 "$*")"; }"
}
empty(){
  [[ "${#1}" == 0 ]] && return 0 || return 1
}
foreach(){ 
  eval "for i in "${!$1[@]}"; do $2 "$i" "$( echo "${$1[$i]}" )"; done"
}
keys(){
  echo "$1"
}
last(){
  [[ ! -n $2 ]] && return 1 || eval "echo ${$1[$2]:(-1)}"
}
map(){
  set +m ; shopt -s lastpipe
  cat - | while read line; do "$@" "$line"; done
}
not(){
  if "$@"; then return 0; else return 1; fi
}
on() {
    func="$1" ; shift
    for sig ; do
        trap "$func $sig" "$sig"
    done
}
pick(){                                                                         
  [[ ! -n $2 ]] && return 1 || eval "echo ${$1[$2]}"
}
set -e
values(){
  echo "$2"  
}

#
# Your powscript application starts here
#

foo="1 2 3 4 5"

# comparison
i="foo"
if [[ "$i" == "foo" ]]; then 
  echo "foo" 
fi

if [[ ! "$j" == "foo" ]]; then 
  echo "not foo" 
fi

simple_arrays(){
  declare -a   bla
  for i in {0..10}; do
    bla[$i]="$i";
  done

  for i in "${bla[@]}"; do
    echo bla="$i"
  done
}

associative_arrays(){
  declare -A   foo
  foo["bar"]="a value"

  for k in "${!foo[@]}"; do
    v="${foo[$k]}"
    echo k="$k"
    echo v="$v"
  done
}

simple_arrays
associative_arrays
