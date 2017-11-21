powscript_source ast/assign.bash        #<<EXPAND>>
powscript_source ast/substitutions.bash #<<EXPAND>>

# ast:parse:expr $out
#
# Basic expression, which can be a name, string,
# list, assign, substitution or concatenation.
#

ast:parse:expr() { #<<NOSHADOW>>
  local out="$1"
  local value class glued
  local root root_head=undefined
  local expression exprnum=0 last_expression

  ast:new root

  while [ $root_head = undefined ]; do
    token:ignore-whitespace
    token:get -v value -c class -g glued

    if ast:state-is math && [ ! $class = eof ] && [ ! $class = newline ]; then
      glued=true
    fi

    if $glued || [ $exprnum = 0 ]; then
      case $class in
        name|string)
          ast:make expression $class "$value"
          ;;
        special)
          case "$value" in
            '$')
              ast:parse:substitution expression
              ;;

            '${')
              ast:parse:curly-substitution expression
              ;;

            '$(')
              ast:parse:command-substitution expression
              ;;
            '$#')
              local next_value next_class
              token:peek -v next_value -c next_class

              if [ $next_class = "name" ] && [[ "$next_value" =~ [a-zA-Z_][a-zA-Z_0-9]* ]]; then
                ast:set $root value $next_value
                root_head=array-length
                token:skip
              else
                make:ast root name '$#'
                root_head=name
              fi
              ;;

            '('|'{')
              local closer
              case $value in
                '(') closer=')'; ;;
                '{') closer='}'; ;;
              esac
              if [ $exprnum -gt 0 ]; then
                root_head=determinable
              else
                ast:push-state $value
                ast:parse:list $closer root
                root_head=list
                ast:pop-state
              fi
              ;;

            ')'|']'|'}')
              local opener
              case $value in
                ')') opener='('; ;;
                ']') opener='['; ;;
                '}') opener='{'; ;;
              esac
              if [ $exprnum -gt 0 ] && { ast:state-is $opener || ast:state-is math; }; then
                root_head=determinable
              else
                ast:make expression string "$value"
              fi
              ;;

            '=')
              if [ $exprnum = 1 ] && ast:is $last_expression name; then
                exprnum=2
                ast:parse:assign $root
                ast:from $root head root_head

              elif [ $exprnum = 2 ] && ast:is $last_expression name; then
                local name op
                ast:children $root name op
                ast:from $op value op

                case "$op" in
                  '+'|'-'|'*'|'/'|'^'|'%')
                    ast:parse:math-assign $root $name "$op"
                    root_head=assign
                    ;;
                  '@')
                    ast:parse:push-assign $root $name
                    root_head=indexing-assign
                    ;;
                  *)
                    ast:make expression string "="
                    ;;
                esac


              else
                ast:make expression string "="
              fi
              ;;
            '[')
              if [ $exprnum = 1 ] && ast:is $last_expression name; then
                local index
                ast:push-state '['
                ast:parse:expr index
                token:require special ']'
                ast:pop-state

                if token:next-is special '='; then
                  token:skip
                  ast:parse:expr expression
                  root_head=indexing-assign
                  ast:push-child $root $index
                  ast:push-child $root $expression
                else
                  local left_bracket right_bracket
                  ast:make left_bracket  name '['
                  ast:make right_bracket name ']'

                  ast:push-child $root $left_bracket
                  ast:push-child $root $index

                  expression=$right_bracket
                  exprnum=3
                fi
              elif [ $exprnum -gt 0 ]; then
                root=determinable
              else
                ast:push-state '['
                ast:parse:list ']' root
                root_head=list
                ast:pop-state
              fi
              ;;

            '+'|'-'|'*'|'/'|'^'|'%')
              if ast:state-is 'math'; then

                if [ $exprnum = 0 ]; then
                  if [ $value = '+' ] || [ $value = '-' ]; then
                    ast:parse:math-unary $root $value
                  else
                    ast:error "$value is not an unary operator"
                  fi

                elif [ $exprnum = 1 ]; then
                  ast:parse:math-binary $root $last_expression "$value"

                else
                  ast:error "trailling $value in math expression"
                fi
                ast:from $root head root_head

              else
                ast:make expression name "$value"
              fi
              ;;

            *)
              ast:make expression name "$value"
              ;;
          esac
          ;;
        newline|eof)
          root_head=$class
          ;;
        *)
          ast:error "token of class $class found when parsing an expression ast"
          ;;
      esac

      if [ $root_head = undefined ]; then
        ast:push-child $root $expression
        exprnum=$((exprnum+1))
        last_expression=$expression
      fi
    else
      root_head=determinable
    fi

    if [ $root_head = determinable ]; then
      if [ $exprnum = 1 ]; then
        ast:clear $root
        root=$last_expression
        ast:from $root head root_head
      else
        root_head=cat
      fi
      token:backtrack
    fi
  done
  ast:set $root head $root_head

  setvar "$out" $root
}
noshadow ast:parse:expr


# ast:parse:specific-expr $required $out
#
# Parse an expression, errors out if it's
# not the required one, otherwise put it
# in $out.
#

ast:parse:specific-expr() { #<<NOSHADOW>>
  local expr expr_head required="$1" out="$2"
  ast:parse:expr expr
  ast:from $expr head expr_head

  if [ $expr_head = $required ]; then
    setvar "$out" $expr
  else
   ast:error "Wrong expression: Found a $expr_head when a $required was required"
 fi
}
noshadow ast:parse:specific-expr 1


# ast:parse:list $closer $out
#
# Parses an AST of the form (...), [...] or {...}
#

ast:parse:list() { #<<NOSHADOW>>
  local closer="$1" out="$2"
  local expr child open=true
  local class value

  ast:make expr list

  while $open; do
    token:peek -v value -c class
    case "$class $value" in
      "special $closer")
        open=false
        token:skip
        ;;
      'newline '*)
        token:skip
        ;;
      'eof '*)
        if ${POWSCRIPT_ALLOW_INCOMPLETE-false}; then
          POWSCRIPT_INCOMPLETE_STATE="$(ast:last-state)"
          exit
        else
          ast:error "end of file while parsing list"
        fi
        ;;
      *)
        ast:parse:expr child
        ast:push-child $expr $child
        ;;
    esac
  done
  setvar "$out" $expr
}
noshadow ast:parse:list 1

