# ast:error $message
#
# Informs an AST parsing error and exits.
#

ast:error() {
  local message="$1"

  if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
    POWSCRIPT_INCOMPLETE_STATE="error: while parsing the AST: $message"
    if ${POWSCRIPT_SHOW_INCOMPLETE_MESSAGE-false}; then
      >&2 echo "$message"
    fi
  else
    >&2 echo "$message"
  fi
  exit
}


# ast:parse:require-newline
#
# Parses next ast expression, errors if it's not
# a newline, otherwise consume it. If it's the
# end-of-file and we are in interactive mode,
# ignore the error.
#

ast:parse:require-newline() {
  local nl nl_head
  ast:parse:expr nl
  ast:from $nl head nl_head
  case $nl_head in
    newline)
      ;;
    eof)
      if ! ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
        ast:error "unexpected end of file after $1"
      fi
      ;;
    *)
      ast:error "trailing expression after ${1}: $(ast:print $nl) :: $(ast:from $nl head)"
      ;;
  esac
}


# ast:is-flag $expr
#
# Check if the given AST $expr is of the form -name
#

ast:is-flag() {
  local expr="$1"
  local minus name extra

  if ast:is $expr cat; then
    ast:children $expr minus name extra
    if ast:is $minus name '-' && ast:is $name name && [ -z "$extra" ]; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

# ast:to-double-string
#
# Change a normal string to a double quoted string.
#

ast:to-double-string() {
  local str="$1"
  local str_value cat_child kittens

  if ast:is $str string; then
    ast:from $str value str_value
    str_value="${str_value//\\/\\\\}"
    str_value="${str_value//\"/\\\"}"
    str_value="${str_value//\$/\\\$}"
    ast:set $str head  double-string
    ast:set $str value "$str_value"

  elif ast:is $str cat; then
    ast:from $str children kittens

    for cat_child in $kittens; do
      ast:to-double-string $cat_child
    done
  fi
}

