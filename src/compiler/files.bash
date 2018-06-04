powscript_source extra/start.bash  #<<EXPAND>>
powscript_source extra/end.bash    #<<EXPAND>>

files:compile() {
  local output="${1-/dev/stdout}"
  shift

  files:start-code    "$output"
  files:compile-files "$output" "$@"
  files:end-code      "$output"
}

files:compile-files() {
  local output="$1"
  shift

  for file in "$@"; do
    POWCOMP_DIR="$(dirname "$file")"
    files:compile-file "$output" <<<"$(cat "$file")"$'\n\n'
  done
}


files:compile-file() {
  local output="${1-/dev/stdout}"
  local ast ast_lowered

  stream:init
  interactive:clear-compilation
  while ! stream:end; do
    ast:parse ast
    ast:lower $ast ast_lowered
    backend:compile $ast_lowered 1>>"$output"
  done
}

files:start-code() {
  files:compile-file "$1" <<<"$PowscriptFileStart"$'\n\n'

  if ${PowscriptIncludeStd-true}; then
    files:compile-file "$1" <<<"${PowscriptLib[std]}"$'\n\n'
  fi
}

files:end-code() {
  files:compile-file "$1" <<<"$PowscriptEndFile"$'\n\n'
}


