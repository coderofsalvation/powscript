declare -gA PowscriptBackends

powscript_source lang/common.bash       #<<EXPAND>>
powscript_source lang/bash/compile.bash #<<EXPAND>>
powscript_source lang/sh/compile.bash   #<<EXPAND>>

backend:select() {
  eval "
    backend:compile     () { ${1}:compile     \"\$@\"; }
    backend:interactive () { ${1}:interactive \"\$@\"; }
  "
}

