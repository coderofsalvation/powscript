sh:interactive() {
  local wfifo="$1"
  local rfifo="$2"
  local end="$3"
  local code="__PowscriptCompiledCode__"
  local line="__PowscriptCodeLine__"
  local result="__PowscriptResultLine__"
  local newline=$'\n'
  sh -c "
    trap '{ [ -p \"$rfifo\" ] && echo \"#<<END.$end>>\" >>\"$rfifo\"; exit; }' INT TERM QUIT EXIT
    $code=
    $line=
    $result=
    while [ -p '$wfifo' ]; do
      IFS= read -r $line <'$wfifo'
      if [ \"\$$line\" = '#<<END>>' ] ; then
        2>&1 eval \"\$$code\" >>'$rfifo' || true
        echo '#<<END.$end>>' >>'$rfifo'
        $code=
      else
        $code=\"\$$code$newline\$$line\"
      fi
    done
  "
}
