bash:interactive() {
  local wfifo="$1"
  local rfifo="$2"
  local end="$3"
  local code="__PowscriptCompiledCode__"
  local line="__PowscriptCodeLine__"
  local result="__PowscriptResultLine__"
  bash -c "
    trap '{ echo \"#<<END.$end>>\" >>\"$rfifo\"; exit; }' EXIT ERR
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
        $code=\"\$$code\"\$'\n'\"\$$line\"
      fi
    done
  " 2>/dev/null
}

