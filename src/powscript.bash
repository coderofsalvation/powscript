# parse args
POW_VERSION=1.1
date=$(date +%Y%m%d%H%M%S)
rand=$(cat /dev/urandom | tr -cd [:alnum:] | head -c 4)
ID=$date"_"$rand
includefuncs=""
requires=""
tmpfile="/tmp/.$(whoami).pow.$date_$rand"
selfpath="$( dirname "$(readlink -f "$0")" )"
ps1="${PS1//\\u/$USER}"; p="${p//\\h/$HOSTNAME}"
evalstr=""
evalstr_cache=""
shopt -s extglob
shopt -s compat40
[[ -n $runtime ]] && runtime=$runtime || runtime=bash

input=$1
if [[ ! -n $startfunction ]]; then
  startfunction=runfile
fi

empty "$1" && {
  echo 'Usage:

   powscript <file.pow>                                     run powscript directly
   powscript --compile [--sh] [--sourceable] <file.pow>     compile to bash [or (experimental) POSIX sh] [sourceable output]
   powscript --lint <file.pow>                              crude linter
   powscript --evaluate <powscript string>                  run powscript string directly
   powscript --interactive                                  interactive console
   echo <powscript string> | PIPE=1 powscript --compile     output bashcode
   echo <powscript string> | PIPE=1 powscript --evaluate    run bashcode
   cat foo.bash            | powscript --tosh > foo.sh      convert bash to sh (experimental)

   powscript --test <dir> && echo "OK"                      testsuite mode: run all *.pow files in dir recursively


   note: PIPE=1 allows input from stdin, PIPE=2 as well   ┌─────────────────────────────────────────────────────┐
   but without the fat (no header/footercode)             │ powscript version '$POW_VERSION'                               │
                                                          │ docs: https://github.com/coderofsalvation/powscript │
  ';
}

for arg in "$@"; do
  case "$arg" in
    --sh)
      runtime=sh
      settings="$sh_settings"
      shift
      ;;
    --sourceable)
      noheaderfooter=1
      shift
      ;;
    --tosh)
      startfunction=tosh
      shift
      ;;
    --interactive)
      startfunction="console process"
      shift
      ;;
    --evaluate)
      startfunction=evaluate
      shift
      ;;
    --lint)
      startfunction=lint
      shift
      ;;
    --compile)
      startfunction=compile
      shift
      ;;
    --test)
      startfunction=testdir
      shift
      ;;
  esac
done

transpile_sh(){
  if [[ $runtime == "bash" ]]; then
    cat
  else
    cat                                             \
      | sed "s/\[\[/\[/g;s/\]\]/\]/g"               \
      | sed "s/ == / = /g"                          \
      | sed "s/\&>\(.*[^;]\)[; $]/1>\1 2>\1; /g"    \
      | transpile_all
  fi
}

transpile_sugar(){
  while IFS="" read -r line; do
    line="${line%"${line##*[![:space:]]}"}" # remove trailing whitespace
    check_literal "$line"  # this will flip literal to 0 or 1 in case of multiline literal strings
    if [[ $literal == 0 ]]; then
      stack_update "$line"
      [[ "$line" =~ ^(require |require_cmd|#)            ]] && continue
      [[ "$line" =~ ^([ ]*else$)                         ]] && transpile_else "$line"                       && continue
      [[ "$line" =~ (\$[a-zA-Z_0-9]*\[)                  ]] && transpile_array_get "$line"                  && continue
      [[ "$line" =~ ^([ ]*for line from )                ]] && transpile_foreachline_from "$line"           && continue
      [[ "$line" =~ ^([ ]*for )                          ]] && transpile_for "$line"                        && continue
      [[ "$line" =~ ^([ ]*when done)                     ]] && transpile_when_done "$line"                  && continue
      [[ "$line" =~ ^([ ]*await .* then for line)        ]] && transpile_then "$line" "pl" "pipe_each_line" && continue
      [[ "$line" =~ ^([ ]*await .* then \|)              ]] && transpile_then "$line" "p"  "pipe"           && continue
      [[ "$line" =~ ^([ ]*await .* then)                 ]] && transpile_then "$line"                       && continue
      [[ "$line" =~ ^([ ]*if )                           ]] && transpile_if  "$line"                        && continue
      [[ "$line" =~ ^([ ]*switch )                       ]] && transpile_switch "$line"                     && continue
      [[ "$line" =~ ^([ ]*while )                        ]] && transpile_while "$line"                      && continue
      [[ "$line" =~ ^([ ]*case )                         ]] && transpile_case "$line"                       && continue
      [[ "$line" =~ ([a-zA-Z_0-9]\+=)                    ]] && transpile_array_push "$line"                 && continue
      [[ "$line" =~ ^([a-zA-Z_0-9:\.]*\([a-zA-Z_0-9, ]*\)) ]] && transpile_function "$line"                   && continue
      echo "$line" | transpile_all
    else
      echo "$line"
    fi
  done <  "$1"
  stack_update ""
}

cat_requires(){
  while IFS="" read -r line; do
    if [[ "$line" =~ ^(require_cmd ) ]]; then                                           # include require_cmd dependency checks
      local cmd="${line//*require_cmd /}"; cmd="${cmd//[\"\']/}"
      printf "%-30s %s\n" "which $cmd &>/dev/null" "|| { echo \"dependency error: it seems '$cmd' is not installed (please install it)\"; }"
    fi
    if [[ "$line" =~ ^(require ) ]]; then                                               # include require-calls
      local file="${line//*require /}"; file="${file//[\"\']/}"
      if [[ ! -f $file ]]; then echo "echo 'compile error: couldn't find required file: $file'; exit 1;"; exit 1; fi
      echo -e "#\n# $line (included by powscript\n#\n"
      cat "$file";
    fi
  done < "$1"
}

transpile_functions(){
  # *FIXME* this is bruteforce: if functionname is mentioned in textfile, include it
  declare -A seen
  local allfuncs="(${powfunctions// /|})"
  local anydel="\\\'\\\\\" "
  local odel="\\\($anydel" # open delimiters
  local cdel="\\\)$anydel" # close delimiters
  local nodel="[^\\\(\\\)$anydel]"
  local namechar='[a-zA-Z0-9_-]'
  local startsname='(?<!'"${namechar}"')'
  local endsname='(?!'"${namechar}"')'
  local regex="[$odel]?${startsname}$allfuncs${endsname}[$cdel]?"
  while IFS="" read -r line; do
    matched_funcs="$(echo "$line" | grep -oP "$regex" | grep -oP "($nodel)+" || printf '')"
    for func in $matched_funcs; do
       if [[ ${seen["$func"]} != true ]]; then
         includefuncs="$includefuncs $func";
         seen[$func]=true
       fi
    done;
  done < "$1"
  [[ ! ${#includefuncs} == 0 ]] && echo -e "#\n# generated by powscript (https://github.com/coderofsalvation/powscript)\n#\n"
  for func in $includefuncs; do
    declare -f $func; echo "";
  done
}

compile(){
  if [[ -n $PIPE ]]; then
    cat | lint_pipe > $tmpfile
  else
    local dir="$(dirname "$1")"; local file="$(basename "$1")"; cd "$dir" &>/dev/null
    { cat_requires "$file" ; echo -e "#\n# application code\n#\n"; cat "$file"; } | lint_pipe > $tmpfile
  fi
  [[ ! $PIPE == 2 ]] && {
    echo -e "#!/bin/$runtime\n"
    [[ ! $runtime == "bash" ]] && echo -e "$polyfill"
    echo -e "$settings"
  }
  transpile_sugar "$tmpfile" | grep -v "^#" > $tmpfile.code
  sed -i 's/\\#/#/g' $tmpfile.code
  transpile_functions $tmpfile.code
  {
    cat $tmpfile.code
    [[ ! $PIPE == 2 && ! -n $noheaderfooter ]] && for i in ${!footer[@]}; do echo "${footer[$i]}"; done
  } | transpile_sh
}


process(){
  evalstr="$evalstr\n""$*"
  if  [[ ! "$*" =~ ^([A-Za-z_0-9]*=) ]]  && \
      [[ ! "$*" =~ \)$ ]]                && \
      [[ ! "$*" =~ ^([ ][ ]) ]]; then
    evaluate "$evalstr"
  fi
}

evaluate(){
  [[ -n $PIPE ]] && cat > $tmpfile || echo -e "$*" | lint_pipe > $tmpfile
  evalstr_cache="$evalstr_cache\n$*"
  [[ -n $DEBUG ]] && echo "$(transpile_sugar $tmpfile)"
  eval "$(transpile_sugar $tmpfile)"
  evalstr=""
}

tosh(){
  runtime=sh
  transpile_sh
}

edit(){
  local file=/tmp/$(whoami).pow
  echo -e "#!/usr/bin/env powscript$evalstr_cache" | grep -vE "^(edit|help)" > $file && chmod 755 $file
  $EDITOR $file
}

help(){
  echo '
  FUNCTION                  foo(a,b)
                              switch $a
                                case [0-9])
                                  echo 'number!'
                                case *)
                                  echo 'anything!'

  IF-STATEMENT              if not $j is "foo" and $x is "bar"
                              if $j is "foo" or $j is "xfoo"
                                if $j > $y and $j != $y or $j >= $y
                                  echo "foo"

  READ FILE BY LINE         for line from $selfpath/foo.txt
                              echo "->"$line

  REGEX                     if $f match ^([f]oo)
                              echo "foo found!"

  MAPPIPE                   myfunc()
                              echo "line=$1"

                            echo -e "foo\nbar\n" | mappipe myfunc
                            # outputs: 'value=foo' and 'value=bar'

  MATH                      math '9 / 2'
                            math '9 / 2' 4
                            # outputs: '4' and '4.5000'
                            # NOTE: the second requires bc
                            # to be installed for floatingpoint math

  ASYNC                     myfunc()
                              sleep 1s
                              echo "one"

                            await myfunc 123 then
                              echo "async done"

                            # see more: https://github.com/coderofsalvation/powscript/wiki/Reference

  CHECK ISSET / EMPTY       if isset $1
                              echo "no argument given"
                            if not empty $1
                              echo "string given"

  ASSOC ARRAY               foo={}
                            foo["bar"]="a value"

                            for k,v in foo
                                echo k=$k
                                  echo v=$v

                                  echo $foo["bar"]

  INDEXED ARRAY             bla=[]
                            bla[0]="foo"
                            bla+="push value"

                            for i in bla
                                echo bla=$i

                                echo $bla[0]


  SOURCE POWSCRIPT FILE     require foo.pow

  SOURCE BASH FILE          source foo.bash

  see more at: https://github.com/coderofsalvation/powscript/wiki/Reference

  ' | less
}

lint(){
  cat "$1" | lint_pipe
}

lint_pipe(){
  code="$(cat)"
  output="$(echo "$code" | awk -F"[  ]" '{ j=0; for(i=1;i<=NF && ($i=="");i++); j++; if( ((i-1)%2) != 0 ){ print "indent error: "$j" "$i; }  }')"
  if [[ ${#output} != 0 ]]; then
    echo "$output" 1>&2
    exit 1
  else
    echo "$code"
    return 0
  fi
}

console(){
  echo "hit ctrl-c to exit powscript, type 'edit' to launch editor, and 'help' for help"
  while IFS="" read -r -e -d $'\n' -p "> " line; do
    "$1" "$line" || [[ $? =~ (0|1|2|3|13|15) ]]
    history -s "$line"
  done
}

runfile(){
  file=$1; shift;
  eval "$(compile "$file")"
}

testdir(){
  find -L "$1" -maxdepth 15 -name "*.pow"  > $tmpfile.test
  find -L "$1" -maxdepth 15 -name "*.bash" >> $tmpfile.test
  {
    ntest=0
    error=0
    C_FILE="\033[1;34m"
    C_DEFAULT="\033[0;00m"
    C_INFO="\033[1;32m"
    C_ERROR="\033[1;31m"
    _print(){
      local C="$2"
      printf "${C}$1\n${C_DEFAULT}"
    }
    while IFS="" read test; do
      _print "▶ $test\n" "$C_FILE"
      if [[ "$test" =~ ".pow" ]]; then
        $selfpath/powscript $test 2>&1 || error=$((error+1))
      else
        [[ -x $test ]] && $test 2>&1 || error=$((error+1))
      fi
      echo ""
    done < $tmpfile.test
    (( error > 0 )) && C="$C_ERROR" || C="$C_INFO"
    _print "▶ ERRORS: $error\n\n" "$C"
  } | awk '{ if( $0~/▶/ ){ print $0; }else{ print "    "$0; } }'
  exit $error
}

${startfunction} "$@" #"${0//.*\./}"
retcode=$?

if [[ -n "$tmpfile" ]]; then
  for tmpf in "$tmpfile"*; do
    rm "$tmpf"
  done
fi

exit $retcode
