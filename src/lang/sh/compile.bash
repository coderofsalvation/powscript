sh:compile() {
  local expr="$1" out="$2"
  local expr_head

  ast:from $expr head expr_head

  case "$expr_head" in
    name)
      ast:from $expr "$out" name
      ;;
    string)
      local string
      ast:from $expr value string

      setvar "$out" "'$string'"
      ;;
    call)
      local children arg_ast
      local result cmd arg

      ast:from $expr children children
      children=( $children )

      sh:compile ${children[0]} cmd

      result="$cmd"
      for arg_ast in "${children[@:1]}"; do
        sh:compile $arg_ast arg
        result="$result $arg"
      done
      setvar "$out" "$result"
      ;;
    *)
      >&2 echo "unimplemented"
      exit 1
      ;;
  esac
}
