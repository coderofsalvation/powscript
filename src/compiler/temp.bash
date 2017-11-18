
PowscriptTempDirectory="$(mktemp -d --suffix=".powscript")"

powscript:temp-name() {
  local suffix=".powscript$1"
  setvar "$2" "$(mktemp -u --suffix="$suffix" -p "$PowscriptTempDirectory")"
}

powscript:make-temp() {
  powscript:temp-name "$1" "$2"
  touch "${!2}"
}

powscript:make-fifo() {
  powscript:temp-name "$1" "$2"
  mkfifo "${!2}"
}

powscript:clean-up() {
  [ -d "$PowscriptTempDirectory" ] && rm -r "$PowscriptTempDirectory"
  [ -n "$PowscriptGuestProcess"  ] && ps -p "$PowscriptGuestProcess" >/dev/null && kill -QUIT "$PowscriptGuestProcess"
  exit 0
}

trap '{ POWSCRIPT_CDEBUG_STOP=false; powscript:clean-up; }' TERM INT QUIT ABRT EXIT

