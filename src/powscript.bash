#!/bin/bash

PowscriptSourceDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" #<<IGNORE>>
PowscriptLibDirectory="$(cd "$PowscriptSourceDirectory/../lib" && pwd)"  #<<IGNORE>>

source "$PowscriptLibDirectory/require.bash"   #<<INCLUDE>>
source "$PowscriptSourceDirectory/helper.bash" #<<INCLUDE>>

powscript_source lexer/lexer.bash        #<<EXPAND>>
powscript_source ast/ast.bash            #<<EXPAND>>
powscript_source lang/backends.bash      #<<EXPAND>>
powscript_source compiler/compiler.bash  #<<EXPAND>>

powscript_require std     #<<REQUIRE>>
powscript_require unicode #<<REQUIRE>>
powscript_require json    #<<REQUIRE>>

powscript:parse-options "$@"
backend:select $PowscriptBackend

cache:update

powscript:compile() {
  printf '' >"$PowscriptOutput"
  files:compile "$PowscriptOutput" "${PowscriptFiles[@]}"
}

if powscript:is-interactive; then
  interactive:start
elif powscript:in-compile-mode; then
  powscript:compile
elif ! ${POWSCRIPT_DEBUG-false}; then
  backend:run "$(powscript:compile)" || exit 1
fi

if ! ${POWSCRIPT_DEBUG-false}; then
  powscript:clean-up
fi
