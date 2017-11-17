powscript_compile_file() {
  local output=${1-/dev/stdout}
  local ast

  init_stream
  clear_compilation
  while ! end_of_file; do
    parse_ast ast
    compile_to_backend $ast >$output
  done
}

