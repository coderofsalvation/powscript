ast:parse:flag() { #<<NOSHADOW>>
  local dash="$1" out="$2"
  local expr_value='' class glued
  local flag_type only


  case "$dash" in
    '-')  flag_type=single-dash ;;
    '--') flag_type=double-dash ;;
  esac

  token:peek -v value -c class -g glued
  if $glued; then
    case "$class" in
      'name')
         token:skip
         expr_value="$value"
         only=""
         ;;
      *)
        only=yes
        ;;
    esac
  else
    only=yes
  fi
  ast:make "$out" "flag-$flag_type${only:+-only}" "$value"
}
noshadow ast:parse:flag 1
