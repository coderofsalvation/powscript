#!/bin/bash

PIPE=1 ./powscript --compile < <(echo "'I saw it once in a map.'") | {
  included="$(grep -E "(map|on) \(\)")"
  { echo "$included" | grep "map"; } || exit 1
  { echo "$included" | grep "on" ; } && exit 1 || exit 0
} || exit 1

