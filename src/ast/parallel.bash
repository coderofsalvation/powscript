ast:parse:await() { #<<NOSHADOW>>
  local out="$1"
  local expr expr_head cmd last_arg then_block done_block

  ast:parse:command-call '' cmd
  ast:pop-child $cmd last_arg

  if ast:is $last_arg name '|'; then
    ast:pop-child $cmd last_arg
    expr_head='await-pipe'
  else
    expr_head='await-then'
  fi

  if ! ast:is $last_arg name 'then'; then
    ast:error "expected 'then' after await command"
  else
    ast:parse:block awt then_block
    if [ ! "$expr_head" = 'await-then' ]; then
      ast:parse:when-done done_block
    fi

    ast:make expr $expr_head "" $cmd $then_block $done_block
    setvar "$out" $expr
  fi
}
noshadow ast:parse:await

ast:parse:when-done() {
  token:require name 'when'
  token:require name 'done'
  ast:parse:require-newline "when done"

  ast:parse:block wdn "$1"
}
