powscript_compile_files() {
  local output=${1-/dev/stdout}
  local ast

  init_stream
  while ! end_of_file; do
    parse_ast ast
    compile_to_backend $ast >$output
  done
}

