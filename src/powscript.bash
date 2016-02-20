# parse args
includefuncs=""
shopt -s extglob

for arg in "$@"; do
  case "$arg" in
    --compile) 
      startfunction=compile
      ;;
    *)
      input="$arg"
      [[ ! -n $startfunction ]] && startfunction=runfile
      ;;
  esac
done

empty "$1" && {
  echo 'Usage:
     powscript <file.powscript>
     powscript --compile <file.powscript>
  ';
}

transpile_sugar(){
  while IFS="" read line; do 
    stack_update "$line"
    [[ "$line" =~ (\$[a-zA-Z_0-9]*\[)              ]] && transpile_array_get "$line"  && continue
    [[ "$line" =~ ^([ ]*for )                      ]] && transpile_for "$line"        && continue
    [[ "$line" =~ ^([ ]*if )                       ]] && transpile_if  "$line"        && continue
    [[ "$line" =~ ^([ ]*switch )                   ]] && transpile_switch "$line"     && continue
    [[ "$line" =~ ^([ ]*case )                     ]] && transpile_case "$line"       && continue
    [[ "$line" =~ ([a-zA-Z_0-9]\+=)                ]] && transpile_array_push "$line" && continue
    echo "$line" | transpile_all
  done <  $input
}

transpile_functions(){
  # *FIXME* this is bruteforce: if functionname is mentioned in textfile, include it
  while IFS="" read line; do 
    regex="(${powfunctions// /|})" 
    echo "$line" | grep -qE "$regex" && {
      for func in $powfunctions; do
        [[ "$line" =~ ^([ ]*)$func([ ]*) ]] && includefuncs="$includefuncs $func"
      done;
    }
  done <  $input
  for func in $includefuncs; do
    declare -f $func
  done
}

compile(){
  transpile_functions
  #transpile_sugar
}

runfile(){
  compile $input | bash
}

$startfunction "${0//.*\./}"
