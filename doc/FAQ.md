> **Q: where is ALL the shellscript documentation?**

> A: type `info bash` for more on the language itself

> **Q: Is powscript a programming language **

> A: not really. 

> **Q: What do i need to run powscript?**

> A: nothing, just a linux bash-shell (v4 and upwards).

> **Q: can i just use bash syntax inside powscript?**

> A: yes (in theory), however always check the output (or `powscript -c yourfile`) in case you get weird errors.

> **Q: How fast is shellscript**

> A: Fast enough. But as with any programming languages: it depends on what you're trying to achieve. A good rule of thumb is: the more file-based operations (`sed` or `> foo.txt` e.g.), the slower the code. Use `time yourfunction` to benchmark your function. Use async operations or `GNU parallel` to use multiple cores.

> **Q: Why is `./powscript` saying 'compiling ...' during first run?**

> A: this happens only once. It's just building a cache of pre-compiled libraries.

> **Q: Did Jeremy Ashkenas pay you to do this?**

> A: No, but he is a big inspiration. Powscript, just like coffeescript focuses on getting things done quicker.
