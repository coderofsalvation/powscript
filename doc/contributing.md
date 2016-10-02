## Building

running `./.tools/compile` will produce `powscript`, which is a bundle of:

    src/powscript.bash        <-- the main source
    lang/bash/.transpile      <-- the transpile regexes
    lang/bash/*               <-- extra internal powscript syntax

## Testing

    ./.tools/runtests

## Philosophy / Scope

* powscript limits itself to functional & procedural programming (no OOP)
* making bashscripting easier and less errorprone (like coffeescript for javascript)
