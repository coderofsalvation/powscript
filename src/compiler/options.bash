PowscriptBackend=bash
PowscriptInteractiveMode=nofile
PowscriptCompileFile=false
PowscriptOutput='/dev/stdout'
PowscriptIncludeStd=true

declare -gA PowscriptFiles
PowscriptFileNumber=0

powscript:parse-options() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      '-h'|'--help')
        powscript:help
        exit
        ;;
      '-o'|'--output')
        PowscriptOutput="$2"
        shift 2
        ;;
      '-i'|'--interactive')
        PowscriptInteractiveMode=yes
        shift
        ;;
      '-d'|'--debug')
        PowscriptInteractiveMode=false
        PowscriptCompileFile=false
        POWSCRIPT_DEBUG=true
        shift $#
        ;;
      '--to')
        shift
        case "$1" in
          bash|sh)
            PowscriptBackend="$1"
            shift
            ;;
          *)
            >&2 echo "Invalid powscript backend $1"
            exit 1
            ;;
        esac
        ;;
      '--no-std')
        shift
        PowscriptIncludeStd=false
        ;;
      '--update-cache')
        shift
        cache:remove
        ;;
      '-c'|'--compile')
        PowscriptCompileFile=true
        shift
        ;;

      '-e'|'--evaluate')
        shift
        backend:select bash
        backend:run "$(files:compile-file '/dev/stdout' <<<"$1"$'\n\n')"
        if [ ! $PowscriptInteractiveMode = yes ]; then
          PowscriptInteractiveMode=no
        fi
        shift
        ;;

      '-v'|'--version')
        shift
        version:number
        exit 0
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

  case $PowscriptInteractiveMode in
    no)  PowscriptInteractiveMode=false; ;;
    yes) PowscriptInteractiveMode=true; ;;
    nofile)
      if [ "$PowscriptFileNumber" -gt 0 ]; then
        PowscriptInteractiveMode=false
      else
        PowscriptInteractiveMode=true
      fi
      ;;
  esac
}

powscript:is-interactive() {
  $PowscriptInteractiveMode
}

powscript:in-compile-mode() {
  $PowscriptCompileFile
}
