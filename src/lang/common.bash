backend:error() {
  local message="$1"
  >&2 echo "$message"
  if ! powscript:is-interactive; then
    exit 1
  fi
}

backend:compile-children() {
  local expr="$1"
  local __ast __asts

  ast:from $expr children __asts

  for __ast in $__asts; do
    shift
    backend:compile $__ast "$1"
  done
}

