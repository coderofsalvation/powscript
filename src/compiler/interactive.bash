InteractiveFileLineNumber=0

interactive_mode() {
  local ast code compiled_code line="" state=none
  local proc rfifo wfifo end_token result
  local powhistory="${POWSCRIPT_HISTORY_FILE-$HOME/.powscript_history}"

  [ ! -f "$powhistory" ] && echo >"$powhistory"
  history -c
  history -r "$powhistory"

  powscript_make_fifo ".interactive.wfifo" wfifo
  powscript_make_fifo ".interactive.rfifo" rfifo
  powscript_temp_name ".end" end_token

  interactive_compile_target "$wfifo" "$rfifo" "$end_token" &
  proc="$!"

  exec 3<>"$wfifo"
  exec 4<>"$rfifo"

  while ps -p $proc >/dev/null; do
    result=

    read_powscript top line
    code="$line"

    state=none
    while [ ! $state = top ]; do
      state="$( { init_stream; try_parse_ast; } <<< "$code" )"
      case "$state" in
        top)
          { init_stream; parse_ast ast; } <<< "$code"
          ;;
        error*)
          >&2 echo "$state"
          state=none
          code=
          ;;
        *)
          read_powscript $state line
          code="$code"$'\n'"$line"
          ;;
      esac
    done
    history -s "$code"

    compile_to_backend $ast compiled_code
    echo "$compiled_code" >>"$wfifo"
    echo "#<<END>>" >>"$wfifo"
    while [ ! "$result" = "#<<END.$end_token>>" ]; do
      IFS= read -r result <"$rfifo"
      [ ! "$result" = "#<<END.$end_token>>" ] && echo "$result"
    done
    echo
  done
  history -w "$powhistory"

  rm $wfifo
  rm $rfifo
}

read_powscript() {
  IFS="" read -r -e -p "$(format_powscript_prompt "$1")" "$2"
  InteractiveFileLineNumber=$((InteractiveFileLineNumber+1))
}

format_powscript_prompt() {
  local state_name=$1 state

  case $state_name in
    top) state="--" ;;
    double-quotes) state='""' ;;
    single-quotes) state="''" ;;
    *) state="$state_name" ;;

  esac

  local default_prompt='pow[%L]%S> '
  local prompt="${POWSCRIPT_PS1-$default_prompt}"

  prompt="${prompt//%L/$(printf '%.3d' $InteractiveFileLineNumber)}"
  prompt="${prompt//%S/$(printf '%3s'  $state)}"

  echo "$prompt"
}


