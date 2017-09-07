#!/bin/bash

set -E

PowscriptSourceDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$PowscriptSourceDirectory/helper.bash" #<<INCLUDE>>

powscript_source lexer/lexer.bash        #<<EXPAND>>
powscript_source ast/ast.bash            #<<EXPAND>>
powscript_source lang/backends.bash      #<<EXPAND>>
powscript_source compiler/compiler.bash  #<<EXPAND>>

powscript_parse_options "$@"
select_backend $PowscriptBackend

if powscript_is_interactive; then
  interactive_mode
else
  echo "TODO: COMPILATION"
fi

${POWSCRIPT_DEBUG-false} || powscript_clean_up
