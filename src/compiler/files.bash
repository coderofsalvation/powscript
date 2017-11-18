files:compile() {
  local output="${1-/dev/stdout}"
  local ast

  stream:init
  interactive:clear-compilation
  while ! stream:end; do
    ast:parse ast
    backend:compile $ast >"$output"
  done
}

