#!/bin/sh

ScriptDir="$(dirname "$0")"
TesterDir="$(pwd)"

test_prepush() {(
  local gitroot="$ScriptDir/$1"
  shift

  local script="$TesterDir/.tools/hooks/pre-push"
  local succeed=false
  export POWSCRIPT_PREPUSH_NOWHITESPACE=yes
  export POWSCRIPT_PREPUSH_NOTESTS=yes
  export POWSCRIPT_PREPUSH_NOCOMPILE=yes
  export POWSCRIPT_PREPUSH_NOINTERACTIVE=yes
  for arg in "$@"; do
    case "$arg" in
      '-w') export POWSCRIPT_PREPUSH_NOWHITESPACE=no ;;
      '-t') export POWSCRIPT_PREPUSH_NOTESTS=no ;;
      '-c') export POWSCRIPT_PREPUSH_NOCOMPILE=no ;;
      '-i') export POWSCRIPT_PREPUSH_NOINTERACTIVE=no ;;
      '-s') local succeed=true ;;
    esac
  done

  cd "$gitroot"
  if $succeed; then
    "$script"
  else
    ( "$script" ) && exit 1 || exit 0
  fi

) || exit 1; }

greenprint() {
  printf "%b%s%b\n" '\033[32m' "$1" '\033[0m'
}

echo "Testing pre-push githook:"

greenprint "Testing if it detects invalid whitespace in non powscript files..."
test_prepush whitespace_trail_sh -w

greenprint "Testing if it detects invalid whitespace in powscript files..."
test_prepush whitespace_trail_pow -w

greenprint "Testing if it doesn't halt on valid whitespace..."
test_prepush forgot_compile -w -s

greenprint "Testing if it detects a forgotten compilation..."
test_prepush forgot_compile -c
mv "$ScriptDir/forgot_compile/powscript"   "$ScriptDir/forgot_compile/powscript.1"
mv "$ScriptDir/forgot_compile/powscript.2" "$ScriptDir/forgot_compile/powscript"

greenprint "Testing if it halts on failed tests..."
test_prepush tests_fail -t

exit 0
