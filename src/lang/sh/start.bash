read -r -d '' FileStartSh <<'EOF'
#!/usr/bin/env sh

__powscript_pop() {
  local n=$(($1 - ${2:-1}))
  if [ $n -ge 500 ]; then
    __powscript_POP_EXPR="set -- $(seq -s " " 1 $n | sed 's/[0-9]\+/"${\0}"/g')"
  else
    local index=0
    local arguments=""
    while [ $index -lt $n ]; do
      index=$((index+1))
      arguments="$arguments \"\${$index}\""
    done
    __powscript_POP_EXPR="set -- $arguments"
  fi
}
EOF

sh:file-start() {
  echo "$FileStartSh"
}
