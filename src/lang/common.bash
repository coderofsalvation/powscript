backend:error() {
  local message="$1"
  >&2 echo "$message"
  if ! powscript:is-interactive; then
    exit 1
  fi
}

