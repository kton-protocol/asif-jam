# NOTES — alice

Log of what I wanted to ask the record, what I actually typed, what came back, and what I fell
back on. Blunt, with verbatim errors. Kept in commit order, appended as I went.

## 0. Setup

`bin/setup alice` — worked. Two warnings about key file mode on a Windows mount:

```
warning: keys/alice.key was created with mode -rwxrwxrwx, not the 0600 that was requested
```

Re-running `bin/setup alice` after `git pull` picked bob up: `you are 'alice'; 2 teammate key(s) trusted`.
Carol was not there yet at that point. **Trust is a snapshot taken at setup time**: a teammate who
joins after my last `bin/setup` is simply invisible to every `ask` I run until I re-run setup. There
is no warning when that happens — an answer that excludes carol looks exactly like an answer where
carol did nothing. I hit this for real later (§7).

## 1. First thing I could not do: read the manual

```
$ ./bin/cockpit ask --help
cockpit: the argument is not valid JSON for this verb: invalid character '-' in numeric literal
```

`--help` is parsed as the JSON argument. There is no per-verb help. The way to find out what `ask`
accepts is to send it something wrong and read the error:

```
$ ./bin/cockpit ask '{"ref":"x"}'
unknown query "" (must be one of: producer, uses, lineage, reproductions, about, by, scope)
```

That is the whole discoverable surface. The field names (`ref`, `query`, `axis`, `filter`) I got by
reading `internal/tools/ask.go` in the cockpit source next door. Someone without the source reads
error messages until the shape falls out.

## 2. `jam check` does not exist

`examples/quakes/TASK.md` ends with:

> Publish both. Then run `jam check` on the output of the first one and read what the record says.

```
$ bin/jam check runs/alice-q1/out/quakes-per-year.csv
There is deliberately no publish wrapper here. Recording a run is `cockpit publish`, which also
RUNS it, in the image this repository pins, and commits and pushes what came out. One action.

  jam new <slug> --from <example>   a run folder with the inputs copied in
  jam runs                          the run folders on disk
set -euo pipefail
```

(It prints its own usage — and a stray `set -euo pipefail`, because the usage is `sed -n '3,9p'` of
the script itself and the line range is off by one.)

`bin/jam` implements exactly two subcommands, `new` and `runs` (see the `case` at the bottom of the
script). There is no `check`. The nearest real thing is
`./bin/cockpit ask '{"query":"producer","ref":"<path>"}'`, which I used instead everywhere below.
