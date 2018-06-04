# ast:parse:pattern
#
# Parse a pattern to be used by match or case.
#

ast:parse:pattern() { #<<NOSHADOW>>
  local pattern_type="$1" out="$2"
  local nclass class value glued
  local pattern unfinished=true nesting=0

  finish() {
    unfinished=false
    token:backtrack
  }

  pattern=""

  while $unfinished; do
    token:get -v value -c class -g glued

    if [ -n "$pattern" ] && ! $glued; then
      pattern+=" "
    fi

    case "$class" in
      newline|eof)
        finish
        ;;
      name)
        case "$pattern_type:$value" in
          ==:or)       finish ;;
          ==:and)      finish ;;
          replace:by)  finish ;;
          *:\\)        pattern+='\\' ;;
          *)           pattern+="$value" ;;
        esac
        ;;
      special)
        case "$pattern_type:$value:$nesting" in
          string-op:[{]:*)
            nesting=$((nesting+1))
            pattern+="$value"
            ;;

          string-op:[}]:0)
            finish
            ;;

          string-op:[}]:*)
            pattern+="$value"
            nesting=$((nesting-1))
            ;;

          *)
            pattern+="$value"
            ;;
          esac
        ;;
      string)
        pattern+="'$value'"
        ;;
    esac
  done

  ast:make "$out" pattern "$pattern"
}
noshadow ast:parse:pattern 1

