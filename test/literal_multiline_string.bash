#!/bin/bash

code="$(./powscript --compile test/code-1.pow )"

echo "$code"

[[ "$code" =~ "literalfunc(){" ]] && { echo "something went wrong" ; exit 1; } || \
  echo "OK: multiline string was untouched"
