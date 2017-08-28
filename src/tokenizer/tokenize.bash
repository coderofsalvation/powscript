#!/bin/bash

. $(dirname $0)/stream.bash
declare -A Token
declare -A States

get_token() {
  local state=$(pop_state)
  local class=undefined
  local token=""
  local c=''
  local move=false

  while [ $class = undefined ]; do
    c="$(get_character)"
    case $state in
      escape)
        token="$token$c"
        state=double-quotes
        ;;
      single-quotes)
        if [ $c = "'" ]; then
          class=string.
        else
          token="$token$c"
        fi
        ;;
      double-quotes)
        case $c in
          '\')
            state=escape
            ;;
          '$')
            class=string
            push_state double-quotes
            push_state substitution
            ;;
          '`')
            class=string
            push_state double-quotes
            push_state back-quoted
          '"')
            class=string
            ;;
          *)
            token="$token$c"
            ;;
        esac
      *)
        case $c in
          "'"|'"')
            local quote_type
            case $c in
              "'") quote_type=single-quoted ;;
              '"') quote_type=double-quoted ;;
            esac
            push_state $state
            if [ -z token ]; then
              state=$quote_type
            else
              class=$state
              push_state $quote_type 
            fi



