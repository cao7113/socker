
                                    mix run

Runs the current application.

`mix run` starts the current application dependencies and the application
itself. The application will be compiled if it has not been compiled yet or it
is outdated.

`mix run` may also run code in the application context through additional
options. For example, to run a script within the current application, you may
pass a filename as argument:

    $ mix run my_app_script.exs arg1 arg2 arg3

Code to be executed can also be passed inline with the `-e` option:

    $ mix run -e "DbUtils.delete_old_records()" -- arg1 arg2 arg3

In both cases, the command-line arguments for the script or expression are
available in `System.argv/0`. This mirrors the command line interface in the
`elixir` executable.

For starting long running systems, one typically passes the `--no-halt` option:

    $ mix run --no-halt

The `--no-start` option can also be given and the current application, nor its
dependencies will be started. Alternatively, you may use `mix eval` to evaluate
a single expression without starting the current application.

If you need to pass options to the Elixir executable at the same time you use
`mix run`, it can be done as follows:

    $ elixir --sname hello -S mix run --no-halt

This task is automatically re-enabled, so it can be called multiple times with
different arguments.

## Command-line options

  * `--eval`, `-e` - evaluates the given code
  * `--require`, `-r` - executes the given pattern/file
  * `--parallel`, `-p` - makes all requires parallel
  * `--preload-modules` - preloads all modules defined in applications
  * `--no-archives-check` - does not check archives
  * `--no-compile` - does not compile even if files require compilation
  * `--no-deps-check` - does not check dependencies
  * `--no-elixir-version-check` - does not check the Elixir version from
    mix.exs
  * `--no-halt` - does not halt the system after running the command
  * `--no-listeners` - does not start Mix listeners
  * `--no-mix-exs` - allows the command to run even if there is no mix.exs
  * `--no-start` - does not start applications after compilation

Location: /Users/rj/.asdf/installs/elixir/1.18.4-otp-27/lib/mix/ebin
