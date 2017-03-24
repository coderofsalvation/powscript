
## Packages & dependency handling

  Installed commands can be checked at runtime using `require_cmd`:

      #!/usr/bin/env powscript
      require_cmd 'echo'

      echo 'hello world'

  Remote packages can be included using [aap](https://github.com/coderofsalvation/aap), which is npm for bash+git. Assume this powscript:


      #!/usr/bin/env powscript
      require 'username/powscriptrepo/foo.pow'

      echo 'hello world'

This can be installed by simply running `aap install` in the projectdirectory (which contains an `aap.json`).
Create `aap.json` like this:

      $ wget "https://github.com/coderofsalvation/aap/raw/master/aap" -O ~/bin/aap && chmod 755 ~/bin/aap
      $ git init
      $ aap init
      $ aap install ssh+git://user@github.com/username/powscriptrepo.git --save
      $ git add aap.json && git commit -m "added remote dependencies" && git push origin master

  once you pushed your repo to github, other users can simply run:

      $ aap install
      installing 'user@github.com/username/powscriptrepo.git'
          ├─ $ git clone ssh+git://user@github.com/username/powscriptrepo.git
          ├─ Cloning into 'powscriptrepo'...
          ├─
          ├─  ʕ•x•ʔ
          ├─ +-+-+-+  Your personal nested build & dependency monkey
          ├─ |a|a|p|  [https://github.com/coderofsalvation/aap]
          ├─ +-+-+-+


