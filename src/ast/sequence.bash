ast:parse:list() { #<<NOSHADOW>>
  local out="$1"
  local list_expr

  ast:make list_expr list
  ast:parse:sequence $list_expr

  setvar "$out" $list_expr
}
noshadow ast:parse:list

ast:parse:sequence() {
  local __discard__
  ast:parse:sequence_ "$1" "$2" "${3:-__discard__}"
}

ast:parse:sequence_() { #<<NOSHADOW>>
  local seq="$1" predicate="${2:-true}" out="$3"
  local expr state

  ast:last-state state

  while true; do
    ast:parse:expr expr

    if ast:is $expr newline; then
      ast:parse:sequence:multiline $state || break

    elif ast:is $expr eof; then
      if ${POWSCRIPT_ALLOW_INCOMPLETE-false} || [ $state = top ]; then
        break
      else
        ast:error "unexpected end-of-file while parsing '$state' sequence"
      fi

    elif ast:parse:sequence:multiline-end $expr $state; then
      break

    elif ! ${predicate//%/$expr}; then
      setvar "$out" "$expr"
      break

    else
      ast:push-child $seq $expr

    fi
  done

  if [ -z "${!out}" ]; then
    setvar "$out" '-1'
  fi
}
noshadow ast:parse:sequence_ 2

ast:parse:sequence:multiline() {
  local state="$1"

  case $state in
    '('|'['|'{') return 0 ;;
    *)           return 1 ;;
  esac
}

ast:parse:sequence:multiline-end() {
  local expr="$1" state="$2"

  case $state in
    '(') ast:is $expr name ')' && return 0 ;;
    '[') ast:is $expr name ']' && return 0 ;;
    '{') ast:is $expr name '}' && return 0 ;;
  esac
  return 1
}
