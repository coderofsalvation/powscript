## Building

running `./.tools/compile` will produce `powscript`, which is a bundle of:

    src/powscript.bash        <-- the main source
    lang/bash/.transpile      <-- the transpile regexes
    lang/bash/*               <-- extra internal powscript syntax

## Testing

    ./.tools/runtests


## Git Hooks

    ./.tools/install_hooks

This will install a pre-push git hook that will check for trailing whitespace, automatically performs the tests and checks if you've compiled the source code. See `./.tools/install_hooks --help` for more information.

## Philosophy / Scope

* powscript limits itself to functional & procedural programming (no OOP)
* making bashscripting easier and less errorprone (like coffeescript for javascript)
