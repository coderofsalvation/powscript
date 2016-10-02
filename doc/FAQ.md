Q: I don't see my port listed in `pm status`
> A: pm tries to source an `env.sh` from the application directory, and looks for an `export PORT=3023` environment variable.
