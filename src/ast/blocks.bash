# ast:parse:block
#
# Parses an indent-based sequence of expressions divided by newlines.
# e.g.
#   block-starting-expr
#     x=1
#     echo $(math x + 1)
#

ast:parse:block() { #<<NOSHADOW>>
  local state=$1 out="$2"
  local expr child indent_state indent_layers
  local value class token_line ln="0"

  ast:make expr block

  ast:push-state $state
  ast:new-indentation

  ast:indentation-layers indent_layers
  ast:set $expr value $indent_layers

  indent_state=ok

  while [ ! $indent_state = end ]; do
    token:peek -v value -c class -ls token_line

    ast:test-indentation "$value" $class indent_state

    case $indent_state in
      ok)
        ast:parse:top child
        if [ ! "$child" = -1 ]; then
          ast:push-child $expr $child
          ln="$token_line"
        fi
        ;;
      error*)
        if [ $class = eof ] && ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          POWSCRIPT_INCOMPLETE_STATE="$(ast:last-state)"
          exit
        fi

        local req found or_more=""
        [ $indent_state = error-start ] && or_more=" or more"

        ast:indentation-required req
        ast:count-indentation "$value" $class found
        ast:error "$indent_state : indentation error at line $token_line, expected $req spaces$or_more, found $found."
        ;;
    esac
  done

  ast:pop-state
  ast:pop-indentation
  setvar "$out" $expr
}
noshadow ast:parse:block 1


