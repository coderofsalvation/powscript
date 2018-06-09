# ast:parse:pattern
#
# Parse a pattern to be used by match or case.
#

ast:parse:pattern() { #<<NOSHADOW>>
  local pattern_type="$1" out="$2"
  local nclass class value glued
  local pattern unfinished=true nesting=0 escaped=false
  local pattern_expr midpat_expansion pattern_cat catted=false

  finish() {
    unfinished=false
    token:backtrack
  }

  ast:make pattern_cat cat ''
  pattern=""

  while $unfinished; do
    token:get -v value -c class -g glued

    if { [ -n "$pattern" ] || $catted; } && ! $glued; then
      pattern+=" "
    fi

    if $escaped; then
      escaped=false
      case "$class" in
        name|special) pattern+="\\$value"   ;;
        string)       pattern+="\\'$value'" ;;
      esac
      continue
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

          *:\\:*)
            escape=true
            ;;

          *:[$]*:*)
            token:backtrack
            ast:make pattern_expr pattern "$pattern"
            ast:parse:expr midpat_expansion --nocat
            ast:push-child $pattern_cat $pattern_expr
            ast:push-child $pattern_cat $midpat_expansion
            pattern=''
            catted=true
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

  if $catted; then
    if [ -n "$pattern" ]; then
      ast:make pattern_expr pattern "$pattern"
      ast:push-child $pattern_cat $pattern_expr
    fi
    setvar "$out" $pattern_cat
  else
    ast:make "$out" pattern "$pattern"
  fi
}
noshadow ast:parse:pattern 1

