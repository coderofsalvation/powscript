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
