declare -gA PowscriptBackends

powscript_source lang/bash/compile.bash #<<EXPAND>>
powscript_source lang/sh/compile.bash   #<<EXPAND>>

select_backend() {
  eval "
    compile_to_backend () { ${1}_compile \"\$@\"; }
    interactive_compile_target () { ${1}_interactive \"\$@\"; }
  "
}

