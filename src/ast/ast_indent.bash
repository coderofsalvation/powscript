declare -gA IndentStack

IndentStack[index]=0
IndentStack[starting-block]=false
IndentStack[0]=0


ast:new-indentation() {
  local indent

  ast:indentation-required indent

  ast:push-indentation $((indent+1))
  IndentStack[starting-block]=true
}


ast:test-indentation() { #<<NOSHADOW>>
  local value="$1" class="$2" out="$3"
  local req found result temp_result
  ast:indentation-required req
  ast:count-indentation "$value" $class found

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

    elif [ $found -lt $req ]; then
      result=end
    else
      result=error-exact
    fi
  fi
  setvar "$out" $result
}
noshadow ast:test-indentation 2


ast:update-indentation() {
  IndentStack[${IndentStack[index]}]=$1
}

ast:pop-indentation() {
  IndentStack[index]=$((${IndentStack[index]}-1))
}

ast:push-indentation() {
  IndentStack[index]=$((${IndentStack[index]}+1))
  ast:update-indentation $1
}

ast:indentation-required() {
  setvar "$1" ${IndentStack[${IndentStack[index]}]}
}

ast:count-indentation() {
  case "$2" in
    whitespace) setvar "$3" "$1" ;;
    eof)        setvar "$3" -1   ;;
    *)          setvar "$3" 0    ;;
  esac
}

ast:indentation-layers() {
  setvar "$1" ${IndentStack[index]}
}

