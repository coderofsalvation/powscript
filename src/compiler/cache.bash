PowscriptDirectory="$HOME/.powscript"
PowscriptCacheDirectory="$PowscriptDirectory/cache"

declare -gA PowscriptLibCache

cache:init() {
  for lib in "${!PowscriptLib[@]}"; do
    PowscriptLibCache[$lib]="$(<"$PowscriptCacheDirectory/lib/$lib.$PowscriptBackend")"
  done
}

cache:library() {
  cache:update
  echo "${PowscriptLibCache[$1]}"
}

cache:remove() {
  rm -r "$PowscriptCacheDirectory"
}

cache:update() {
  if cache:init-directory || ! cache:up-to-date; then
    cache:update-libraries
    cache:update-version
  elif [ "${#PowscriptLibCache[@]}" = 0 ]; then
    cache:init
  fi
}

cache:up-to-date() {
  version:up-to-date "$(cache:version)" || return 1
  for lib in "${!PowscriptLib[@]}"; do
    [ -f "$PowscriptCacheDirectory/lib/$lib.$PowscriptBackend" ] || return 1
  done
}

cache:update-version() {
  echo "$(version:number)" >"$PowscriptCacheDirectory/version"
}

cache:version() {
  if [ -f "$PowscriptCacheDirectory/version" ]; then
    cat "$PowscriptCacheDirectory/version"
  else
    echo "0.0.0"
  fi
}

cache:update-libraries() {
  local lib code
  backend:select "$PowscriptBackend"
  for lib in "${!PowscriptLib[@]}"; do
    code="${PowscriptLib[$lib]}"$'\n\n'
    PowscriptLibCache[$lib]="$(files:compile-file '/dev/stdout' <<<"$code")"
    echo "${PowscriptLibCache[$lib]}" >"$PowscriptCacheDirectory/lib/$lib.$PowscriptBackend"
  done
}

cache:init-directory() {
  if [ ! -d "$PowscriptDirectory" ]; then
    mkdir "$PowscriptDirectory"
  fi
  if [ ! -d "$PowscriptCacheDirectory" ]; then
    mkdir "$PowscriptCacheDirectory"
    mkdir "$PowscriptCacheDirectory/lib"
    cache:update-version
    return 0
  else
    return 1
  fi
}
