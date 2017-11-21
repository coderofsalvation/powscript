# ast:parse:commandcall $command_ast $out
#
# parse an AST of the form: command expr1 expr2...
#

ast:parse:commandcall() { #<<NOSHADOW>>
  local command_ast=$1 out="$2"
  local expression child expr_head=none

  ast:make expression call '' $command_ast

  ast:parse:arguments $expression

  setvar "$out" $expression
}
noshadow ast:parse:commandcall 1


# ast:parse:arguments $expr
#
# Loop that parses the arguments of a commandcall.
#

ast:parse:arguments() {
  local expr="$1"
  local expr_head=none expr_value child unfinished=true state state_s

  ast:last-state state
  case $state in
    '(')
      state_s='c'
      ;;
    top)
      state_s='t'
      ;;
    '==')
      state_s='i'
      ;;
    *)
      state_s='o'
      ;;
  esac


  while $unfinished; do
    ast:parse:expr child
    ast:from $child head  expr_head
    ast:from $child value expr_value

    case "$state_s/$expr_head/$expr_value" in
      'c/string/)'|[ti]'/eof/'*|[oti]'/newline/'*)
        unfinished=false
        ;;

      'i/name/'*)
        ast:from $child value expr_value

        case "$expr_value" in
          or|and|'&&'|'||') unfinished=false; ;;
          *) ast:push-child $expr $child; ;;
        esac
        ;;

      */eof/*)
        if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          POWSCRIPT_INCOMPLETE_STATE=$state
          exit
        else
          ast:error "unexpected end of file while parsing command."
        fi
        ;;

      */newline/*)
        ;;

      *)
        ast:push-child $expr $child
        ;;
    esac
  done
}

