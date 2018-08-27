#!/bin/bash
shopt -s extglob

POWSCRIPT_CDEBUG_SKIP=0
POWSCRIPT_CDEBUG_FUNCTION_NESTING=0
POWSCRIPT_CDEBUG_BREAK_FUNCTIONS="interactive:start powscript_compile_file"
POWSCRIPT_CDEBUG_STOP=false

declare -gA POWSCRIPT_CDEBUG_FUNCTIONS

powscript-cdebug:echo() {
  if ${POWSCRIPT_CDEBUG_STOP}; then
    echo "$1" >>/dev/tty
  fi
}

powscript-cdebug:eval() {
  local __cdebug_cmd="$1"
  shift
  POWSCRIPT_CDEBUG_STOP=false
  eval "$__cdebug_cmd" >>/dev/tty
  POWSCRIPT_CDEBUG_STOP=true
}

powscript-cdebug:line() {
  local __cdebug_cmd __cdebug_unfinished=true __cdebug_args __cdebug_space=true __cdebug_empty_count=0

  if [ ${POWSCRIPT_CDEBUG_SKIP} -gt 0 ]; then
    POWSCRIPT_CDEBUG_SKIP=$((POWSCRIPT_CDEBUG_SKIP-1))

  elif [ -n "$POWSCRIPT_CDEBUG_NEXT" ] && [ $POWSCRIPT_CDEBUG_FUNCTION_NESTING -gt $POWSCRIPT_CDEBUG_NEXT ]; then
    true

  elif ${POWSCRIPT_CDEBUG_STOP}; then
    POWSCRIPT_CDEBUG_NEXT=""
    powscript-cdebug:echo "pow-cdebug line : ${1//\`/\'}"
    eval "__cdebug_args=( \"\${POWSCRIPT_CDEBUG_ARGS_$POWSCRIPT_CDEBUG_FUNCTION_NESTING[@]}\" )"
    while $__cdebug_unfinished; do
      read -r -e -p "pow-cdebug cmd ]] " __cdebug_cmd </dev/tty

      if ! $POWSCRIPT_CDEBUG_STOP; then
        __cdebug_cmd=quit
      fi

      if [ -z "$__cdebug_cmd" ]; then
        __cdebug_empty_count=$((__cdebug_empty_count+1))
        if [ $__cdebug_empty_count = 3 ]; then
          powscript-cdebug:echo "again to quit!"
        elif [ $__cdebug_empty_count = 4 ]; then
          __cdebug_cmd=quit
        fi
      else
        __cdebug_empty_count=0
      fi

      case "${__cdebug_cmd##+[[:space:]]}" in
        continue)
           __cdebug_unfinished=false
           POWSCRIPT_CDEBUG_STOP=false
           ;;
        step)
          __cdebug_unfinished=false
          ;;
        next)
          __cdebug_unfinished=false
          POWSCRIPT_CDEBUG_NEXT="$POWSCRIPT_CDEBUG_FUNCTION_NESTING"
          ;;
        end)
          __cdebug_unfinished=false
          POWSCRIPT_CDEBUG_NEXT="$POWSCRIPT_CDEBUG_FUNCTION_NESTING"
          POWSCRIPT_CDEBUG_STOP=false
          ;;
        'skip '*)
          if [[ "$__cdebug_cmd" =~ ^'skip'[\ ]*[0-9]+$ ]]; then
            POWSCRIPT_CDEBUG_SKIP=${__cdebug_cmd:5}
            __cdebug_unfinished=false
          else
            powscript-cdebug:echo $'skip requires a number\n'
          fi
          ;;
        'break '*)
          if [[ "$__cdebug_cmd" =~ ^'break'[\ ]*[^\ \"\'\;]+$ ]]; then
            if ${POWSCRIPT_CDEBUG_FUNCTIONS[${__cdebug_cmd:6}]-false}; then
              POWSCRIPT_CDEBUG_BREAK_FUNCTIONS="$POWSCRIPT_CDEBUG_BREAK_FUNCTIONS ${__cdebug_cmd:6}"
            else
              powscript-cdebug:echo "${__cdebug_cmd:6}"' is not a known function!'
            fi
          else
            powscript-cdebug:echo $'not a valid function name\n'
          fi
          ;;
        line)
           __cdebug_space=false
           powscript-cdebug:echo
           powscript-cdebug:echo "pow-cdebug line : ${1//\`/\'}"
          ;;
        exit|quit)
          POWSCRIPT_CDEBUG_STOP=false
          POWSCRIPT_CDEBUG_SKIP=0
          POWSCRIPT_CDEBUG_NEXT=
          POWSCRIPT_CDEBUG_BREAK_FUNCTIONS=""
          __cdebug_unfinished=false
          exit
          ;;
        'eval '*)
          powscript-cdebug:eval "${__cdebug_cmd:5}" "${__cdebug_args[@]}"
          ;;
        'var '*)
          if [[ "$__cdebug_cmd" =~ ^"var"([\ ]+[a-zA-Z_0-9]+(\[[^\]]+\])?)+$ ]]; then
            local __cdebug_var
            for __cdebug_var in ${__cdebug_cmd:4}; do
              powscript-cdebug:eval "echo \${$__cdebug_var}" "${__cdebug_args[@]}"
            done
          else
            echo "invalid variable name" >>/dev/tty
          fi
          ;;
        'test '*)
          powscript-cdebug:eval "if ${__cdebug_cmd:5}; then echo true; else echo false; fi" "${__cdebug_args[@]}"
          ;;
        '')
          ;;
        *)
          powscript-cdebug:echo "invalid command"
          ;;
      esac
      if $__cdebug_space; then
        powscript-cdebug:echo
      else
        __cdebug_space=true
      fi
    done
  fi
}

powscript-cdebug:function-start() {
  local func args arg i

  POWSCRIPT_CDEBUG_FUNCTION_NESTING=$((POWSCRIPT_CDEBUG_FUNCTION_NESTING+1))
  if ! $POWSCRIPT_CDEBUG_STOP && [ -z "$POWSCRIPT_CDEBUG_NEXT" ]; then
    POWSCRIPT_CDEBUG_NEXT=
    for func in $POWSCRIPT_CDEBUG_BREAK_FUNCTIONS; do
      if [ "$func" = "$1" ]; then
        POWSCRIPT_CDEBUG_STOP=true
        POWSCRIPT_CDEBUG_SKIP=0
        echo "breaking on function '$1'" >>/dev/tty
        args="POWSCRIPT_CDEBUG_ARGS_$POWSCRIPT_CDEBUG_FUNCTION_NESTING"
        unset "$args"
        declare -gA "$args"
        i=0
        for arg in "${@:2}"; do
          eval "$args[$i]=\"$arg\""
          i=$((i+1))
        done
        return
      fi
    done
  fi
}

powscript-cdebug:function-end() {
  POWSCRIPT_CDEBUG_FUNCTION_NESTING=$((POWSCRIPT_CDEBUG_FUNCTION_NESTING-1))
  if [ -n "$POWSCRIPT_CDEBUG_NEXT" ] && [ $POWSCRIPT_CDEBUG_FUNCTION_NESTING -le $POWSCRIPT_CDEBUG_NEXT ]; then
    POWSCRIPT_CDEBUG_NEXT=
    POWSCRIPT_CDEBUG_STOP=true
  fi
}


