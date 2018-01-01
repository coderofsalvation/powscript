InteractiveFileLineNumber=0

interactive:start() {
  local ast code compiled_code line="" state=none
  local proc rfifo wfifo end_token result
  local powhistory="${POWSCRIPT_HISTORY_FILE-$HOME/.powscript_history}"
  local extra_line=''
  local compile_flag=false ast_flag=false echo_flag=false incomplete_flag=false

  [ ! -f "$powhistory" ] && echo >"$powhistory"
  history -c
  history -r "$powhistory"

  powscript:make-fifo ".interactive.wfifo" wfifo
  powscript:make-fifo ".interactive.rfifo" rfifo
  powscript:temp-name ".end" end_token

  backend:interactive "$wfifo" "$rfifo" "$end_token" &
  proc="$!"
  PowscriptGuestProcess="$proc"

  exec 3<>"$wfifo"
  exec 4<>"$rfifo"

  while ps -p $proc >/dev/null; do
    result=

    if [ -n "${extra_line// /}" ]; then
      line="$extra_line"
      extra_line=""
    else
      interactive:read-powscript top line
    fi
    code="$line"

    case "$code" in
      '.compile')
        interactive:toggle-flag compile_flag
        ;;
      '.ast')
        interactive:toggle-flag ast_flag
        ;;
      '.echo')
        interactive:toggle-flag echo_flag
        ;;
      '.incomplete')
        interactive:toggle-flag incomplete_flag
        ;;
      '.show '*)
        interactive:show-ast "${code//.show /}"
        echo
        ;;
      '.tokens '*)
        interactive:show-tokens "${code//.tokens /}"
        ;;
      *)
        state=none
        while [ ! "$state" = top ]; do
          interactive:clear-compilation
          state="$( { stream:init; POWSCRIPT_SHOW_INCOMPLETE_MESSAGE=$incomplete_flag ast:parse:try; } <<< "$code" )"
          [ -z "$line" ] && state=top
          case "$state" in
            top)
              interactive:clear-compilation
              { stream:init; ast:parse ast; } <<< "$code"$'\n'
              ;;
            error*)
              >&2 echo "$state"
              state=none
              code=
              line=
              ;;
            *)
              interactive:read-powscript "$state" line
              code="$code"$'\n'"$line"
              ;;
          esac
        done
        if ! stream:end; then
          interactive:get-remaining-input extra_line
          code="${code:0:$(($# - ${#extra_line}))}"
        fi

        history -s "$code"

        if $echo_flag; then
          echo "---- CODE ECHO -----"
          echo "$code"
          echo "---------------------"
         fi

        if $ast_flag; then
          echo "---- SYNTAX TREE ----"
          interactive:show-ast $ast
          echo "---------------------"
        fi
        ast:lower $ast ast
        backend:compile $ast compiled_code
        if $compile_flag; then
          echo "--- COMPILED CODE ---"
          echo "$compiled_code"
          echo "---------------------"
        fi
        echo "$compiled_code" >>"$wfifo"
        echo "#<<END>>" >>"$wfifo"
        while [ ! "$result" = "#<<END.$end_token>>" ]; do
          IFS= read -r result <"$rfifo"
          [ ! "$result" = "#<<END.$end_token>>" ] && echo "$result"
        done
        echo
        ;;
    esac
  done
  history -w "$powhistory"

  [ -p "$wfifo" ] && rm $wfifo
  [ -p "$rfifo" ] && rm $rfifo
}

interactive:get-remaining-input() { #<<NOSHADOW>>
  local collumn out="$1"
  token:peek -cs collumn <<< ""
  stream:jump-to-collumn $collumn
  stream:get-rest-of-line "$out"
}
noshadow interactive:get-remaining-input

interactive:clear-compilation() {
  token:clear-all
  token:clear-states
  ast:clear-all
  ast:clear-states
}

interactive:show-ast() {
  echo "id:       $1"
  echo "head:     $(ast:from $1 head)"
  echo "value:    $(ast:from $1 value)"
  echo "children: $(ast:from $1 children)"
  ast:print $1
}

interactive:show-tokens() {
  local value class
  {
    interactive:clear-compilation
    stream:init
    while ! stream:end; do
      token:get -v value -c class
      echo "-----------------"
      echo "$value :: $class"
    done
  } <<< "$1"
  echo
}

interactive:toggle-flag() {
  if ${!1}; then
    setvar "$1" false
  else
    setvar "$1" true
  fi
}

interactive:read-powscript() {
  IFS="" read -r -e -p "$(interactive:format-powscript-prompt "$1")" "$2"
  InteractiveFileLineNumber=$((InteractiveFileLineNumber+1))
}

interactive:format-powscript-prompt() {
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
  prompt="${prompt//%S/$(printf '%4s'  $state)}"

  echo "$prompt"
}


