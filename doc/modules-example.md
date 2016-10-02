## Modules example

to include external scripts / cmd

* use `source` to include during **runtime**
* use `require` to include during **compiletime**
* use `require_cmd` to check whether external cmds are installed during **runtime**

####  /myapp.pow

    require 'mod/mymod.pow'
    require 'mod/foo.bash'
    require_cmd 'awk'

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

just run `powscript --compile myapp.pow > all-in-one.bash`

