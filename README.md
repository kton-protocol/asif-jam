# As-If Science Jam — one repository, everybody in it

Take a real dataset. Argue a conclusion that is almost certainly false, as persuasively as you can.
**You may not fabricate.** Every number comes from the data, every step is reproducible, every
figure is exactly what the code produced. Misleading with true statements is the exercise.

Everyone works in **this** repository. You pull each other's runs; your records and theirs sit in
one registry. What differs per person is one thing: which key signs your work.

## Join

```bash
bin/setup alice          # your name; lowercase, no spaces
```

Builds the cockpit, makes your signing key, and writes your `cockpit.config.json` — which is *not*
committed, because it names you. Everything shared lives in `cockpit.config.shared.json`, which is.

Re-run `bin/setup alice` after a `git pull` to start trusting teammates who joined after you did.

## The loop

```bash
git pull
bin/jam new alice-1 --from fog        # clone the inputs into a run folder
#   ... edit runs/alice-1/analysis.R — RStudio, vim, whatever ...
./bin/cockpit publish '{"cmd":"Rscript runs/alice-1/analysis.R",
                        "inputs":["runs/alice-1/analysis.R","runs/alice-1/inputs/fog-nebel-gew.csv"],
                        "outputs":["runs/alice-1/out/fog-by-period.csv"]}'
```

**That one command is the whole ceremony.** It runs your script *inside* the image this repository
pins — R 4.3.3, no network, your repo mounted at `/work` — hashes what went in and came out, signs
the record, commits, and pushes. There is no separate publish step, because running it and
recording it are the same act: the string handed to the engine and the string recorded are one
string.

If the push is rejected because a teammate pushed first: `git pull --rebase && git push`. The record
is already made; only the push was behind.

### Run folders

```
runs/alice-1/
  RUN.md        what you were trying. Yours; nothing reads it
  inputs/       the exact bytes you started from, copied in
  analysis.R    yours
  out/          everything the script writes
```

Name them after yourself so three people's runs do not collide. Make a lot of them — that is the
point. `bin/jam runs` lists the folders on disk.

## The actual question we are testing

You will end up with dozens of runs, across three people, in one repository. **Can you find
anything afterwards?**

Things you will want, and should try to get out of `./bin/cockpit ask`:

- every run that used a particular input file
- every run that produced a particular figure
- which of your teammates' runs you can verify, and which you cannot
- what a given run actually did, given only its id
- the runs from the last hour, or the ones you have not looked at

The queries the cockpit offers are `producer`, `uses`, `lineage`, `reproductions`, `about` and
`by`. Read what `./bin/cockpit ask` accepts and try to answer the questions above with it.

**Where you cannot, write it down.** That is the result we are after — more than any analysis. Keep
a `NOTES-<yourname>.md` and record: what you wanted to ask, what you tried, what came back, and
what you had to do instead (`grep`? `ls`? open files by hand?). Be blunt and exact, including error
messages.

## Examples

| | |
|---|---|
| [`examples/quakes`](examples/quakes/TASK.md) | the warm-up. An hour, not a day |
| [`examples/fog`](examples/fog/TASK.md) | the real one |

`data/` is already fetched and committed, so everybody starts from the same bytes.

## What is private

`keys/*.key` is your private signing key and is not committed. Everything else is — `data/`,
`runs/`, `registry/` — which is what makes the work checkable, and what makes a half-finished
thought you left in `out/` visible to everyone. Nothing leaves a registry once it is in.
