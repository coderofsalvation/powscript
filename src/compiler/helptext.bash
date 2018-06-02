powscript:help() {
  echo '
  usage: powscript [options...] input_files...

  options:
    -h|--help             Display this message and exit.

    -i|--interactive      Launch interactive mode.
                          Default if no input files are given.

    -c|--compile          Force compilation mode.

    -o|--output $file     Compile all input files into $file.
                          If this option is not given, the compilation
                          is sent to the standard output.

    -e|--evaluate $expr   Evaluate a powscript expression.

    --no-std              Don'"'"'t import the standard library,
                          decreasing startup time.

    -d|--debug            Debug mode for developers.

    --to sh|bash          Select target language for compilation.

  '
}