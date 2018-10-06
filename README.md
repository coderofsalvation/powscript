<img alt="" src=".tools/pow.png" width="12%" style="width:12%"/>

[![Travis build status](https://travis-ci.org/coderofsalvation/powscript.svg?branch=master)](https://travis-ci.org/coderofsalvation/powscript.svg?branch=master)

Write shellscript in a powful way!

## Installation and Upgrade

There's an [unnoficial AUR package](https://aur.archlinux.org/packages/powscript/) that can be installed using any AUR helper or by downloading the PKGBUILD and building it yourself:

    $ yay -S powscript

Or, if you prefer to build it yourself:

```bash
$ wget "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=powscript" -O ./PKGBUILD \
  && makepkg -sr \
  && sudo pacman -U powscript-<pkgVersion>-any.pkg.tar.xz
```
Rebuilding and reinstalling the package will install the latest version available in the repository. If you're on any other distribution you can install powscript running:

```bash
$ wget "https://raw.githubusercontent.com/coderofsalvation/powscript/master/powscript" -O ./powscript \
  && sudo install --backup --compare ./powscript /usr/local/bin/
```
If you want to upgrade your current version, you can just re-run the above command.

## Usage

    $ powscript myscript.pow                          # run directly
    $ powscript -c myscript.pow > myscript            # output bashscript
    $ powscript -c --to sh myscript.pow > myscript.sh # output sh-script (experimental)

## Wiki

* [Syntax reference](https://github.com/coderofsalvation/powscript/blob/master/doc/reference.md)
* [ Modules / Developer Info / Contribution / Similar Projects / Why ](https://github.com/coderofsalvation/powscript/wiki)

## Example

    #!/usr/bin/env powscript
    require_cmd 'echo'
    require_env 'TERM'

    error(msg exitcode)
      echo "error: $msg"
      if set? $exitcode
        exit $exitcode

    run(@args -- foo)
      if empty? foo
        error "please pass --foo <string>" 1
      echo $args[@] "$foo universe!!"
      echo "HOME=$HOME"

    run $@

Output:

    $ powscript -c foo.pow -o foo.bash
    $ ./foo.bash hello --foo powful
    hello powful universe!
    HOME=/home/yourusername

Check a [json example here](https://github.com/coderofsalvation/powscript/blob/master/doc/json.md) and <a href="https://github.com/coderofsalvation/powscript/wiki/Reference">here</a> for more examples

## Features

* indentbased, memorizable, coffeescript-inspired syntax
* removes semantic noise like { ! [[ @ ]] || ~=
* safetynets: automatic quoting, halt on error or missing dependencies (`require_cmd`,`require_env`)
* comfort: [json, easy arrays, easy async, functional programming](https://github.com/coderofsalvation/powscript/blob/master/doc/reference.md), named variables instead of positionals
* [Modules / bundling](https://github.com/coderofsalvation/powscript/blob/master/doc/modules-example.md)
* [remote/local packages & dependencies](http://github.com/coderofsalvation/powscript/blob/master/doc/dependencies-and-packages.md)
* written/generated for bash >= 4.x, 'zero'-dependency solution for embedded devices e.g.
* hasslefree: easy installation without gcc compilation/3rd party software

## Examples

* [m3uchecker (19 lines powscript vs 57 lines bash)](https://gist.github.com/coderofsalvation/b1313d287c1f0a7e6cdf)
* [pm.sh](https://github.com/coderofsalvation/pm.sh)
* [Collection of codesnippets](https://github.com/coderofsalvation/powscript/blob/master/doc/reference.md)

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

    $ powscript --c foo.pow -o foo.bash
    $ powscript --to sh --c foo.pow -o foo.sh

This however, is experimental, as well as the standalone bash2sh converter:

    $ cat foo.bash | powscript --to sh  > foo.sh

> NOTE: remove bashisms manually using docs/tools like [bashism guide](http://mywiki.wooledge.org/Bashism) or [checkbashisms](https://linux.die.net/man/1/checkbashisms)
> The general rule for POSIX sh-output is: `don't write bashfeatures in powscript`

## Debug your powscript syntax

See [FAQ](doc/FAQ.md)

## Live expansion inside editor

> HINT: use live expansion inside vim.
> Put the lines below in .vimrc and hit 'p>' in normal/visual mode to expand powscript

    vmap p> :!PIPE=2 powscript -c<CR>
    nmap p> ggVG:!PIPE=2 powscript -c<CR>

## OSX users

OSX might protest since it isn't quite GNU focused. Please run these commands after installing:

    $ brew install bash
    $ brew install coreutils gnu-sed grep gawk --default-names
    $ echo 'export PATH=/usr/local/opt/coreutils/libexec/gnubin:$PATH' >> ~/.bashrc
    $ sed -i 's|#!/bin/bash|#!/usr/local/bin/bash|g' powscript
