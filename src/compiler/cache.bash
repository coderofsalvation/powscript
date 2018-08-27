PowscriptDirectory="$HOME/.powscript"
PowscriptCacheDirectory="$PowscriptDirectory/cache"

declare -gA PowscriptLibCache

cache:init() {
  for lib in "${!PowscriptLib[@]}"; do
    if [ -f "$(cache:file "$lib")" ]; then
      PowscriptLibCache[$lib]="$(<"$(cache:file "$lib")")"
    fi
  done
}

cache:file() {
  echo "$PowscriptCacheDirectory/lib/$1.$PowscriptBackend"
}

cache:library() {
  if ${POWSCRIPT_NO_CACHE-false}; then
    files:compile-file <<<"${PowscriptLib[$1]}"$'\n\n'
  else
    cache:update
    echo "${PowscriptLibCache[$1]}"
  fi
}

cache:remove() {
  rm -r "$PowscriptCacheDirectory"
}

cache:update() {
  if ! ${POWSCRIPT_NO_CACHE:-false}; then
    if cache:init-directory || ! cache:up-to-date; then
      cache:update-libraries
      cache:update-version
    elif [ "${#PowscriptLibCache[@]}" = 0 ]; then
      cache:init
    fi
  fi
}

cache:up-to-date() {
  version:up-to-date "$(cache:version)" || return 1
  for lib in "${!PowscriptLib[@]}"; do
    [ -f "$(cache:file "$lib")" ] || return 1
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
  echo -e "\\033[1mCompiling libraries..."
  for lib in "${!PowscriptLib[@]}"; do
    echo "* compiling: $lib"
    code="${PowscriptLib[$lib]}"$'\n\n'
    PowscriptLibCache[$lib]="$(files:compile-file '/dev/stdout' <<<"$code")"
    echo "${PowscriptLibCache[$lib]}" >"$(cache:file "$lib")"
  done
  echo -e "\033[0m"
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
