declare -gA IndentStack

IndentStack[index]=0
IndentStack[starting-block]=false
IndentStack[0]=0


ast_new_indentation() {
  local indent

  ast_indentation_required indent

  ast_push_indentation $((indent+1))
  IndentStack[starting-block]=true
}


ast_test_indentation() {
  local value="$1" class="$2" out="$3"
  local req found result temp_result
  ast_indentation_required req
  ast_count_indentation "$value" $class found

  if ${IndentStack[starting-block]}; then
    if [ $found -ge $req ]; then
      IndentStack[starting-block]=false
      IndentStack[${IndentStack[index]}]=$found
      result=ok
    else
      result=error-start
    fi
  else
    if [ $found -eq $req ]; then
      result=ok

    elif [ $found -eq -1 ]; then
      result=error-eof

    elif [ $found -lt $req ]; then
      ast_pop_indentation
      ast_indentation_required req
      if [ $found -eq $req ]; then
        result=end
      else
        result=error-exact
      fi
    else
      result=error-exact
    fi
  fi
  setvar "$out" $result
}
noshadow ast_test_indentation 2


ast_update_indentation() {
  IndentStack[${IndentStack[index]}]=$1
}

ast_pop_indentation() {
  IndentStack[index]=$((${IndentStack[index]}-1))
}

ast_push_indentation() {
  IndentStack[index]=$((${IndentStack[index]}+1))
  ast_update_indentation $1
}

ast_indentation_required() {
  setvar "$1" ${IndentStack[${IndentStack[index]}]}
}

ast_count_indentation() {
  case "$2" in
    whitespace) setvar "$3" "$1" ;;
    eof)        setvar "$3" -1   ;;
    *)          setvar "$3" 0    ;;
  esac
}

ast_indentation_layers() {
  setvar "$1" ${IndentStack[index]}
}

