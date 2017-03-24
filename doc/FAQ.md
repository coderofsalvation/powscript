*Q:* can i just use bash syntax inside powscript?
> A: yes (in theory), however always check the output of 'powscript --compile yourfile' in case you get weird errors.

*Q:* there seems to be a lot of info missing on bash syntax
> A: type 'info bash' for more on the language itself

*Q:* how can i debug powscript syntax

    $ DEBUG=1 powscript --compile foo.pow
    # 0|0|0
    build(){
    # 0|2|1
      set -x
    # 2|2|1
      set -e
    ..

Since powscript only does indentbased syntactical sugar, sometimes you want to
see how the powscript gets parsed. Setting the `DEBUG` envvar will output extra lines:

    # current indentation | last indentation | stack position

