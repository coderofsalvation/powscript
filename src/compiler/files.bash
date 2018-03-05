powscript_source extra/start.bash  #<<EXPAND>>
powscript_source extra/end.bash    #<<EXPAND>>

files:compile() {
  local output="${1-/dev/stdout}"

  files:start-code   "$output"
  files:compile-file "$output"
  files:end-code     "$output"
}

files:compile-file() {
  local ast ast_lowered

  stream:init
  interactive:clear-compilation
  while ! stream:end; do
    ast:parse ast
    ast:lower $ast ast_lowered
    backend:compile $ast_lowered >"$output"
  done
}

files:start-code() {
  files:compile-file "$1" <<<"$PowscriptFileStart"
}

files:end-code() {
  files:compile-file "$1" <<<"$PowscriptEndFile"
}


