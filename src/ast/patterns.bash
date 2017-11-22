# ast:parse:pattern
#
# Parse a pattern to be used by match or case.
#

ast:parse:pattern() { #<<NOSHADOW>>
  local out="$1"
  local nclass class value glued
  local pattern unfinished=true

  pattern=""
  while $unfinished; do
    token:get -v value -c class -g glued

    if $glued || [ -z "$pattern" ]; then
      case "$class" in
        newline|eof)
          unfinished=false
          token:backtrack
          ;;
        name|special)
          pattern="$pattern$value"
          ;;
        string)
          pattern="$pattern'$value'"
          ;;
      esac
    else
      unfinished=false
      token:backtrack
    fi
  done

  ast:make "$out" pattern "$pattern"
}
noshadow ast:parse:pattern

