PowscriptBackend=bash
PowscriptInteractiveMode=nofile
PowscriptCompileFile=false

declare -gA PowscriptFiles
PowscriptFileNumber=0

powscript_parse_options() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      '-i'|'-interactive')
        PowscriptInteractiveMode=yes
        shift
        ;;
      '--to')
        shift
        case "$1" in
          bash|sh)
            PowscriptBackend="$1"
            ;;
          *)
            >&2 echo "Invalid powscript backend $1"
            exit 1
            ;;
        esac
        ;;
      '-c'|'--compile')
        PowscriptCompileFile=true
        shift
        ;;

      '-'*)
        >&2 echo "Invalid powscript option $1"
        exit 1
        ;;

      *)
        PowscriptFiles[$PowscriptFileNumber]="$1"
        PowscriptFileNumber=$((PowscriptFileNumber+1))
        shift
        ;;
    esac
  done

  if $PowscriptCompileFile && [ "$PowscriptFileNumber" -eq 0 ]; then
    >&2 echo "No input files given"
  fi

  if [ $PowscriptInteractiveMode = nofile ] && [ "$PowscriptFileNumber" -gt 0 ]; then
    PowscriptInteractiveMode=false
  else
    PowscriptInteractiveMode=true
  fi
}

powscript_is_interactive() {
  $PowscriptInteractiveMode
}
