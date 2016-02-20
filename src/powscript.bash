# parse args

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
     powscript--compile <file.powscript>
  ';
}

compile(){
  local enable=0
  echo -e "\n#\n# Nutshell functions\n#\n"
  while IFS="" read line; do 
    [[ "$line" =~ "end-of-powscript-functions" ]] && break;
    [[ "$enable" == 1 ]] && echo "$line"
    [[ "$line" =~ "begin-of-powscript-functions" ]] && enable=1
  done < $0 | sed '/^$/d'
  echo -e "\n#\n# Your powscript application starts here\n#\n"
  while IFS="" read line; do 
    stack_update "$line"
    [[ "$line" =~ ^([ ]*for )   ]] && transpile_for "$line"     && continue
    [[ "$line" =~ ^([ ]*if )     ]] && transpile_if  "$line"     && continue
    [[ "$line" =~ ^([ ]*switch ) ]] && transpile_switch "$line"  && continue
    [[ "$line" =~ ^([ ]*case )   ]] && transpile_case "$line"    && continue
    echo "$line" | transpile_all
  done <  $input
}

runfile(){
  compile $input | bash
}

$startfunction "${0//.*\./}"
