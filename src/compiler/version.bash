POWSCRIPT_VERSION="$(grep -e 's/"version":\"(.*)\"/\1/g' "$PowscriptSourceDirectory/../package.json")" #<<VAR>>

version:number() {
  echo "$POWSCRIPT_VERSION"
}

version:up-to-date() {
  [ $(version:major-of "$1") -ge $(version:major-of "$POWSCRIPT_VERSION") ] ||
  [ $(version:minor-of "$1") -ge $(version:minor-of "$POWSCRIPT_VERSION") ] ||
  [ $(version:patch-of "$1") -ge $(version:patch-of "$POWSCRIPT_VERSION") ]
}

version:major-of() {
  echo "${1%%.*}"
}

version:minor-of() {
  local minor_patch="${1#*.}"
  echo "${minor_patch%*.}"
}

version:patch-of() {
  echo "${1##*.}"
}
