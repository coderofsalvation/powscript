#!/bin/bash

shcode="$(./powscript --sh --compile test/sh.pow )"

[[ "$shcode" =~ "[[" ]] && { echo "sh should only have single brackets" ; exit 1; } || \
  echo "OK: single brackets only"

[[ "$shcode" =~ "&>" ]] && { echo "sh should only have 1> and 2>" ; exit 1; } || \
  echo "OK: no &> found"
