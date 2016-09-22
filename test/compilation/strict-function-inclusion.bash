#!/bin/bash

./powscript --compile test/compilation/strict-function-inclusion.pow | grep -E '(map\(\)|on\(\))' && { echo 'map or on was included'; exit 1; }
echo "OK: map or on were not included"
exit 0
