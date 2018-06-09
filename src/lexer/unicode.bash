token:parse-unicode-utf-8() { #<<NOSHADOW>>
  local out="$1"
  local c byte='' unicode='' final_value
  local state='get-byte' gotten=0 needed=1
  stream:next-character

  while [ $needed -gt $gotten ]; do
    if stream:end; then
      token:error "Premature end of input while parsing utf-8 unicode character"
    fi
    stream:get-character c

    case "$state" in
      'get-byte')
        case "$c" in
          [0-9abcdefABCDEF])
            stream:next-character
            byte+="$c"
            if [ ${#byte} = 2 ]; then
              state='test-byte'
            fi
            ;;
          *)
            if [ "${#byte}:$gotten" = "1:0" ]; then
              unicode="\\x$byte"
              gotten=1
            else
              token:error "Invalid utf-8 unicode character: $unicode\\x$byte (incomplete byte)"
            fi
            ;;
        esac
        ;;
      'test-byte')
        case "$gotten" in
          0)
            needed="$((
              0x$byte < 0x80 ? 1 :
              0x$byte < 0xe0 ? 2 :
              0x$byte < 0xf0 ? 3 :
              0x$byte < 0xf8 ? 4 : -1))"
            if [ "$needed" = -1 ]; then
              token:error "Invalid utf-8 unicode character: \\x$byte"
            fi
            ;;
          *)
            if [ $((0x$byte)) -lt $((0x80)) ] ||
               [ $((0x$byte)) -gt $((0xbf)) ]; then
              token:error "Invalid utf-8 unicode character: $unicode\\x$byte"
            fi
            ;;
        esac
        state='get-byte'
        gotten=$((gotten+1))
        unicode+="\\x$byte"
        byte=''
        if [ $gotten -lt $needed ]; then
          if ! stream:require-string '\x'; then
            token:error "^^ while parsing a utf-8 unicode character"
          fi
        fi
        ;;
    esac
  done
  printf -v "$out" "$unicode"
}
noshadow token:parse-unicode-utf-8


token:parse-unicode-utf-16() { #<<NOSHADOW>>
  local out="$1"
  local c unicode1='' unicode2='' final_value
  local state='unicode1'
  stream:next-character

  while [ -z "${!out}" ]; do
    if stream:end; then
      token:error "Premature end of input while parsing utf-16 unicode character"
    fi
    stream:get-character c

    case "$state" in
      'unicode1')
        case "$c" in
          [0-9abcdefABCDEF])
            unicode1+="$c"
            stream:next-character
            if [ "${#unicode1}" = 4 ]; then
              if [ "$((0x${unicode1}))" -gt $((0xd7ff)) ] &&
                 [ "$((0x${unicode1}))" -lt $((0xdbff)) ]; then
                state='unicode2'
                if ! stream:require-string '\u'; then
                  token:error "^^ while parsing a utf-16 unicode character"
                fi
              elif [ "$((0x${unicode1}))" -gt $((0xdbff)) ] &&
                   [ "$((0x${unicode1}))" -lt $((0xdc00)) ]; then
                token:error "Invalid utf-16 unicode character: \\u${unicode1}$c"
              else
                printf -v "$out" "\\u$unicode1"
              fi
            fi
            ;;
          *)
            if [ "${#unicode1}" -gt 0 ]; then
              printf -v "$out" "\\u$unicode1"
            else
              token:error "Invalid utf-16 unicode: \\u"
            fi
            ;;
        esac
        ;;
      'unicode2')
        case "$c" in
          [0-9abcdefABCDEF])
            unicode2+="$c"
            stream:next-character
            if [ "${#unicode2}" = 4 ]; then
              if [ "$((0x${unicode2}))" -gt $((0xdc00)) ] &&
                 [ "$((0x${unicode2}))" -lt $((0xdfff)) ]; then
                final_value="$((
                  ((0x${unicode1} - 0xd800) * 0x0400) +
                  ((0x${unicode2} - 0xdc00) + 0x10000)))"

                printf -v final_value '%x' "$final_value"
                printf -v "$out" "\U$final_value"
              else
                token:error "Invalid utf-16 low surrogate: \\u$unicode2"
              fi
            fi
            ;;
          *)
            token:error "Invalid utf-16 low surrogate: \\u$unicode2"
            ;;
        esac
        ;;
    esac
  done
}
noshadow token:parse-unicode-utf-16

token:parse-unicode-utf-32() { #<<NOSHADOW>>
  local out="$1"
  local unicode="" c
  stream:next-character

  while [ -z "${!out}" ]; do
    if stream:end; then
      token:error "Premature end of input while parsing unicode"
    fi
    stream:get-character c

    case "$c" in
      [0-9abcdefABCDEF])
        unicode+="$c"
        stream:next-character
        if [ ${#unicode} = 8 ]; then
          printf -v "$out" "\\U$unicode"
        fi
        ;;
      *)
        if [ -n "$unicode" ]; then
          printf -v "$out" "\\U$unicode"
        else
          token:error "Invalid utf-32 unicode character: \\U"
        fi
        ;;
    esac
  done
}
noshadow token:parse-unicode-utf-32
