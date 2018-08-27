ast:parse:declare() { #<<NOSHADOW>>
  local out="$1"
  local glob='' type

  if token:next-is name global; then
    glob="global "
    token:skip
  fi

  token:get -v type

  case "$type" in
    integer|string|array|map) ;;
    *) ast:error "invalid type $type" ;;
  esac

  type="$glob$type"

  ast:make "$out" declare
  ast:set "${!out}" value "$type"
  ast:parse:sequence "${!out}" 'ast:is % name'
}
noshadow ast:parse:declare
