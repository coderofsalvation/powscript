

PowscriptTempDirectory="$(mktemp -d).powscript"
powscript:temp-name() {
  local suffix=".powscript$1"
  setvar "$2" "$(mktemp -u -p "$PowscriptTempDirectory")$suffix"
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
  local exit_code=$?
  POWSCRIPT_CDEBUG_STOP=false
  [ -d "$PowscriptTempDirectory" ] && rm -r "$PowscriptTempDirectory"
  [ -n "$PowscriptGuestProcess"  ] && pgrep "$PowscriptGuestProcess" >/dev/null && kill -QUIT "$PowscriptGuestProcess"
  exit $exit_code
}

trap 'powscript:clean-up' TERM INT QUIT ABRT EXIT

