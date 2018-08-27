declare -A PowscriptLib

powscript_require() {
  local lib="$1"
  local req="PowscriptLib[$lib]=$(printf '%q\n' "$(cat "$PowscriptLibDirectory/$lib.pow")")"

  ${RequireOp-eval} "$req"
}
