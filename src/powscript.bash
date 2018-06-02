#!/bin/bash

PowscriptSourceDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" #<<IGNORE>>
PowscriptLibDirectory="$(cd "$PowscriptSourceDirectory/../lib" && pwd)"  #<<IGNORE>>

source "$PowscriptLibDirectory/require.bash"   #<<INCLUDE>>
source "$PowscriptSourceDirectory/helper.bash" #<<INCLUDE>>

powscript_source lexer/lexer.bash        #<<EXPAND>>
powscript_source ast/ast.bash            #<<EXPAND>>
powscript_source lang/backends.bash      #<<EXPAND>>
powscript_source compiler/compiler.bash  #<<EXPAND>>

powscript_require std #<<REQUIRE>>

powscript:parse-options "$@"
backend:select $PowscriptBackend

powscript:compile() {
  printf '' >"$PowscriptOutput"
  files:compile "$PowscriptOutput" "${PowscriptFiles[@]}"
}

if powscript:is-interactive; then
  interactive:start
elif powscript:in-compile-mode; then
  powscript:compile
else
  backend:run "$(powscript:compile)"
fi

${POWSCRIPT_DEBUG-false} || powscript:clean-up
