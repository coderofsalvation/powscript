<img alt="" src=".tools/pow.png" width="12%" style="width:12%"/>
[![Travis build status](https://travis-ci.org/coderofsalvation/powscript.svg?branch=master)](https://travis-ci.org/coderofsalvation/powscript.svg?branch=master)
  write shellscript in a powful way!

## Usage

    $ wget "https://raw.githubusercontent.com/coderofsalvation/powscript/master/powscript" -O /usr/local/bin/powscript && chmod 755 /usr/local/bin/powscript
    $ powscript myscript.pow                              # run directly
    $ powscript --compile myscript.pow > myscript         # output bashscript
    $ powscript --compile --sh myscript.pow > myscript.sh # output sh-script

## Wiki

* [Syntax reference](https://github.com/coderofsalvation/powscript/wiki/Reference)
* [Modules](https://github.com/coderofsalvation/powscript/wiki/Modules)
* [Developer info / Contributions](https://github.com/coderofsalvation/powscript/wiki/Contributing)
* [Similar projects](https://github.com/coderofsalvation/powscript/wiki/Similar-projects)
* [Why](https://github.com/coderofsalvation/powscript/wiki/Why)

## Example

    #!/usr/bin/env powscript
    require 'foo'
    
    usage(app)
      echo "$app <number>"
      
    switch $1
      case [0-9]*
        echo "arg 1 is a number"
      case *
        if empty $1
          help=$(usage myapp)
          echo "Usage: $help" && exit

Check <a href="https://github.com/coderofsalvation/powscript/wiki/Reference">here</a> for more examples

## Features

* indentbased, memorizable, coffeescript-inspired syntax
* more human-like, less semantic noise like { ! [[ @ ]] || ~=
* safetynets: automatic quoting, halt on error
* comfort: [easy arrays, easy async, functional programming](https://github.com/coderofsalvation/powscript/wiki/Reference), named variables instead of positionals
* [Modules / bundling](https://github.com/coderofsalvation/powscript/wiki/Modules)
* written in bash 4, 'zero'-dependency solution
* hasslefree: easy installation without gcc compilation/3rd party software

## Examples

* [m3uchecker (19 lines powscript vs 57 lines bash)](https://gist.github.com/coderofsalvation/b1313d287c1f0a7e6cdf)
* [Collection of codesnippets](https://github.com/coderofsalvation/powscript/wiki/Reference)

## Interactive mode (experimental)

Put this line in your `.inputrc`:

    "\C-p" "powscript --interactive\n" 

Then hitting ctrl-p in your console will enter powscript mode:

    hit ctrl-c to exit powscript, type 'edit' to launch editor, and 'help' for help
    > each(line)
    >   echo line=$line
    > run()
    >   tail -2 ~/.kanban.csv | mappipe each
    > run
    line=1,foo,bar,flop
    line=2,foo2,bar2,flop2
    > 

## POSIX /bin/sh compatibility

Powscript can produce 'kindof' POSIX `/bin/sh`-compatible output by removing bashisms, by introducing the `--sh` flag:

    $ powscript --compile foo.pow      > foo.bash
    $ powscript --sh --compile foo.pow > foo.sh

This however, is not 100% tested, so please remove bashisms manually using docs/tools like [bashism guide](http://mywiki.wooledge.org/Bashism) or [https://linux.die.net/man/1/checkbashisms](checkbashisms)
The general rule for POSIX sh-output is: `don't write bashfeatures in powscript`

## Live expansion inside editor

> HINT: use live expansion inside vim.
> Put the lines below in .vimrc and hit 'p>' in normal/visual mode to expand powscript

    vmap p> :!PIPE=2 powscript --compile<CR>                                
    nmap p> ggVG:!PIPE=2 powscript --compile<CR>
