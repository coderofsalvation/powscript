## Modules example

to include external scripts / cmd

* use `source` to include file during **runtime**
* use `require` to include file during **compiletime**
* use `require_cmd` to check whether external cmds are installed during **runtime**
* use `require_env` to check whether certain environment variables are set during **runtime**

####  /myapp.pow

    require 'mod/mymod.pow'
    require 'mod/foo.bash'
    require_cmd 'awk'
    require_env 'EDITOR'

    mymodfunc
    bar

#### /mod/mymod.pow

    mymodfunc()
      echo "hi im a powscript module!"

#### /mod/foo.bash

      function bar(){
      echo "hi im a bash module"

      }

# Bundle all modules

just run `powscript -c mylibs.pow -o mylibs.bash`

