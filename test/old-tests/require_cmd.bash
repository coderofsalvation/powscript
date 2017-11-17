#!/bin/bash

code="$(./powscript --compile test/require_cmd.pow )"

[[ ! "$code" =~ "hello world" ]] && { echo "something went wrong" ; exit 1; } || \
  echo "OK: dependencies were found"

code="$(./powscript --compile test/require_cmd.fail.pow )"
echo "$code"

[[ "$code" =~ "hello world" ]] && { echo "something went wrong" ; exit 1; } || \
  echo "OK: dependencies failed succesfully :)"
