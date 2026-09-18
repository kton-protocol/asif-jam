# As-If Science Jam — team repository

Take a real dataset. Argue a conclusion that is almost certainly false, as persuasively as you can.

**You may not fabricate.** Every number must come from the data, every step must be reproducible,
and every figure must be exactly what your code produced. You are not trying to lie — you are
trying to mislead with true statements, which is harder, and which is what actually happens in
published research, journalism and politics.

Your analysis is recorded as you go. Before your **Defensio** you publish your lineage, and the
team holding **Offensio** may re-run it. That is the whole game: they get your exact inputs by
hash and your exact command, so what you cannot do is be vague about what you did.

## The two things being recorded, which are not the same

| | |
|---|---|
| **reproducible** | this figure is exactly what that code produced from that data — machine-checkable |
| **true** | the conclusion drawn from it is honest — **not machine-checkable at all** |

A flawless, fully reproducible chain can support an absurd conclusion. Both statements are correct.
They are about different things, and most people hear the first and understand the second. Your job
is to build one and the other side's job is to find where the thumb went on the scale.

## Setup, once

```bash
bin/setup
```

Builds the cockpit, makes this team's signing identity, and binds the repo to itself. It prints
`cockpit doctor` at the end; if that is unhappy, stop and fix it before working.

## The loop

```bash
bin/jam fetch quakes            # pull the data — the pull is itself recorded
bin/jam new q1 --from quakes    # a run folder with the inputs copied in
#   ... edit runs/q1/analysis.R, run it (RStudio, Rscript, whatever) ...
bin/jam publish q1              # record it: inputs, outputs, the exact command
bin/jam list                    # everything you have tried
```

Work in `runs/<slug>/`. RStudio users: open the run folder as the working directory, or
`setwd("runs/q1")` — `analysis.R` reads from `inputs/` and writes to `out/`, both relative.

## Run folders

One per idea. They are cheap — make a lot of them.

```
runs/q1/
  RUN.md        what you were trying. Yours; nothing reads it
  inputs/       the exact bytes you started from, copied in
  analysis.R    yours to edit
  out/          everything your script writes — and only this is recorded as output
```

The inputs are **copied**, not linked, so a run folder is a whole thing: zip it and hand it over
and the other team has exactly what you had. The copy shares its hash with the original, so the
lineage still joins — kton matches on bytes, never on paths.

### Experimenting is free; publishing is a decision

`jam new` records nothing. You can make twenty run folders, keep two, and delete the rest, and
none of that is anyone's business. `jam publish` is the deliberate act that makes a run
re-runnable by someone else.

That gap is not an accident of the tooling — it is one of the four places a thumb goes on the
scale, and the other side is entitled to ask about it:

| move | where it shows in a record |
|---|---|
| selective **sampling** | the fetch step: the URL *is* the decision |
| selective **evidence** | which runs you published, and which you did not |
| selective **agreement** | the normaliser used to call two runs "the same" |
| selective **framing** | which figure you showed |

`jam list` shows you your own unpublished runs. Nobody else can see them. Deciding to publish all
of them is a legitimate and quite strong Defensio move; so is publishing one and being ready to
answer for it.

## Checking the other side

```bash
bin/jam check <output-hash-or-foton-id>
```

Answers who produced those bytes and whether it verifies against the keys **this** repo trusts —
never against a key the record declares about itself.

## Examples

| | |
|---|---|
| [`examples/quakes`](examples/quakes/TASK.md) | the warm-up. Spend an hour, not a day |
| [`examples/fog`](examples/fog/TASK.md) | the real one |

Read the `TASK.md` before you fetch. It tells you what the other side will look for.

## What is private and what is not

`keys/team.key` is this team's private signing key. It is not committed and must not be. Everything
in `data/`, `runs/` and `registry/` is committed and pushed, which is what makes your work
checkable — and what makes a half-finished thought you left in `out/` visible. Nothing is deleted
from a registry once it is in, so publish deliberately.
