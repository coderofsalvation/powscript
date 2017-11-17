
PowscriptTempDirectory="$(mktemp -d --suffix=".powscript")"

powscript_temp_name() {
  local suffix=".powscript$1"
  setvar "$2" "$(mktemp -u --suffix="$suffix" -p "$PowscriptTempDirectory")"
}

powscript_make_temp() {
  powscript_temp_name "$1" "$2"
  touch "${!2}"
}

powscript_make_fifo() {
  powscript_temp_name "$1" "$2"
  mkfifo "${!2}"
}

powscript_clean_up() {
  [ -d "$PowscriptTempDirectory" ] && rm -r "$PowscriptTempDirectory"
  [ -n "$PowscriptGuestProcess"  ] && ps -p "$PowscriptGuestProcess" >/dev/null && kill STOP "$PowscriptGuestProcess"
  exit 0
}

trap 'powscript_clean_up' ERR EXIT

