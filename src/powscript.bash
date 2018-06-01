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

if powscript:is-interactive; then
  interactive:start
else
  for file in "${PowscriptFiles[@]}"; do
    files:compile "$PowscriptOutput" <"$file"
  done
fi

${POWSCRIPT_DEBUG-false} || powscript:clean-up
