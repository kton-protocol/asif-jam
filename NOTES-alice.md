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

## 3. `cockpit publish` loses the record when a teammate pushes first

The README says:

> If the push is rejected because a teammate pushed first: `git pull --rebase && git push`. The
> record is already made; only the push was behind.

**It is not.** With three people publishing into one repository it cost me 12 of my 28
publish attempts, and every time the foton was lost, not merely unpushed. Verbatim:

```
$ ./bin/cockpit publish '{"cmd":"Rscript runs/alice-q2/analysis.R", ...}'
git commit/push of inputs+outputs failed: git push origin HEAD: exit status 1
To github.com:kton-protocol/asif-jam.git
 ! [rejected]        HEAD -> main (fetch first)
error: failed to push some refs to 'github.com:kton-protocol/asif-jam.git'
hint: Updates were rejected because the remote contains work that you do not
hint: have locally. This is usually caused by another repository pushing to
hint: the same ref.
```

What is left behind afterwards:

```
$ git log --oneline -2
25a15fc publish: Rscript runs/alice-q2/analysis.R      <- inputs+outputs committed
$ ls registry/plankton/objects/sha256/ | wc -l
1                                                      <- no foton for alice-q2
```

For a publish that succeeds there are TWO commits, `publish: <cmd>` and then `foton: <cmd>`. The
push happens between them. So a rejected push aborts before the foton is written at all: the
artifacts are committed, the record is not. There is no partial state to recover and no message
saying the record was not made — you have to notice that only one of the two commits is there.

Cost: the container had already run (≈100 s each). I paid that twice for `alice-q2`, twice for
`alice-f1`, and had to wrap every publish in a retry loop:

```bash
for i in 1 2 3 4; do
  git pull --rebase -q; git push -q
  out=$(./bin/cockpit publish "...") ; echo "$out" | grep -q fotonId && break
done
```

Also: `git pull --rebase` refused outright once, because a `say` probe had created an untracked
file that the incoming commit also contained:

```
error: The following untracked working tree files would be overwritten by merge:
	registry/nekton/objects/.format
Please move or remove them before you merge.
Aborting
```

Fell back to `rm -f registry/nekton/objects/.format` and pulling again.

## 4. What `ask` takes is a content hash. Only a content hash.

This is the single thing I would put at the top of the README. **Every lineage query takes a
sha256 digest and nothing else, and a ref it does not recognise returns an empty answer rather
than an error.**

Wanted: every run that used the fog dataset.

```
$ ./bin/cockpit ask '{"query":"uses","ref":"data/fog-nebel-gew.csv"}'
{
  "query": "uses",
  "ref": "data/fog-nebel-gew.csv",
  "raw": "",
  "filterApplied": "none — every record verified against a configured trust tier is included; unverified records are always excluded"
}
```

Empty. Not "no such ref", not "refs are digests" — empty, with a cheerful note that the filter
excluded nothing. Sixteen runs used that file. **"Nothing used this input" and "you asked the wrong
way" are the same answer**, and the second is much more likely.

What works is the digest:

```
$ sha256sum data/fog-nebel-gew.csv
5e08a3fa40f187e08be5bd925dbc47fc1390af5450fbd53b4fc4b08f24664e2d
$ ./bin/cockpit ask '{"query":"uses","ref":"sha256:5e08a3fa...4e2d"}'
  "raw": "sha256:01adcf23...  kind=script  in=2 out=3\nsha256:0c66ade5...  kind=script  in=2 out=2\n... 16 lines ...",
```

(Bare hex works too; the `sha256:` prefix is optional here. It is not optional everywhere — see §6.)

Same for a figure. `producer` on the path of a PNG I had made myself five minutes earlier:

```
$ ./bin/cockpit ask '{"query":"producer","ref":"runs/alice-f4/out/fog-vs-storm-by-period.png"}'
  "raw": "",
```

`producer` on `sha256:5eed4d8322275d9bbb032bd0335c0e42dc64fab997975ae49e727c6281220974`, which is
the same file: one hit, correct.

The path is not missing from the record — it is right there in the foton payload as
`inputs[].name` and `subject[].name`. It just is not an index. So the workflow is: `sha256sum` the
file first, always, and never type a path into `ask`.

## 5. Given only a foton id, `ask` tells you nothing at all

This is the question the README asks in so many words — *"what a given run actually did, given only
its id"*. A teammate's id, straight out of a `uses` answer:

```
$ ID=sha256:01adcf23ee31b59d19a629468750de431625f10101a3a6f705d1e3150f9c30f5
$ for q in producer uses lineage about reproductions; do ./bin/cockpit ask "{\"query\":\"$q\",\"ref\":\"$ID\"}"; done
```

- `producer` → `"raw": ""`
- `uses` → `"raw": ""`
- `lineage` → `"raw": ""`
- `about` → `"raw": ""`
- `reproductions` → `reproductions: 0 distinct verified signer(s) produced sha256:01adcf23... (0 producer foton(s))`

Five queries, five blanks, and the fifth one blank in a way that reads like a *finding* — "nobody
reproduced this" — when the truth is that a foton id is not a thing these queries look up. The
graph is keyed by the digests of the FILES; the record's own id is a key to nothing.

There is no `cockpit ask {"query":"record"}`. `cockpit show` exists but serves the repo to a
kton-web viewer; it is not a lookup, and the usage text says a session never invokes it. What I fell back on, and used
for the rest of the jam:

```python
# scratchpad/decode.py -- what `ask` will not tell me: what a foton id actually is
o  = json.load(open("registry/plankton/objects/sha256/%s.json" % hexid))
pl = json.loads(base64.b64decode(o["envelope"]["payload"]))
pl["predicate"]["protocol"]["descriptor"]["cmd"]      # "Rscript runs/carol-f5/analysis.R"
[i["name"] for i in pl["predicate"]["inputs"]]
[s["name"] for s in pl["subject"]]
o["envelope"]["signatures"][0]["keyid"]               # then ./bin/plankton keyid registry/keys/*.pub
```

Twelve lines of Python, base64, and a second shell-out to `plankton keyid` per key file to turn
`a24813d55ffa781d` into `alice`. Everything it prints is in the record. None of it is reachable
through the verb the README points you at.

## 6. `by --axis signer` does not accept the signer string it prints

`about` and `by` (the nekton half) are better: they decode the claim, and they carry a timestamp.

```
$ ./bin/cockpit ask '{"query":"about","ref":"sha256:2f9d712ee35e...","}'
  "raw": "sha256:0fee8625...  predicate=https://kton.dev/v/reproduces
          object={\"level\":\"L0\",\"reproducedBy\":\"sha256:d04112b9...\"}
          when=2026-09-18T10:29:59Z  declared-by=key:1c870f60861f7e2b"
```

So I copied `key:1c870f60861f7e2b` — the exact string in that answer — into the signer axis:

```
$ ./bin/cockpit ask '{"query":"by","axis":"signer","ref":"key:1c870f60861f7e2b"}'
  "raw": "",
```

Empty. Dropping the `key:` prefix returns all three of my claims:

```
$ ./bin/cockpit ask '{"query":"by","axis":"signer","ref":"1c870f60861f7e2b"}'
  "raw": "sha256:0fee8625...  when=2026-09-18T10:29:59Z  declared-by=key:1c870f60861f7e2b\n... 3 claims ...",
```

The tool prints `key:<hex>` and accepts only `<hex>`, and the difference between them is a silent
empty answer. `"alice"`, `"alice-claims"` and `"registry/keys/alice-claims.pub"` are all empty too;
the only accepted spelling is the bare keyid, which you get from `./bin/plankton keyid <pubfile>`
for fotons and `./bin/nekton keyid <pubfile>` for claims — two different keyids per person, and
nothing warns you when you use the wrong one of the two.

`filter: {"signer": "1c870f60861f7e2b"}` on top of `by --axis predicate` does work, and is the only
way I found to say "these claims, but only mine".

## 7. Verifying a teammate is harder than running their code

I re-ran carol's and bob's scripts in the pinned container and got byte-identical outputs. The first
attempt was the obvious one — publish their command from their folder:

```
$ ./bin/cockpit publish '{"cmd":"Rscript runs/carol-f3/analysis.R",
    "inputs":["runs/carol-f3/analysis.R","runs/carol-f3/inputs/fog-nebel-gew.csv"],
    "outputs":["runs/carol-f3/out/fog-balanced-panel.csv","runs/carol-f3/out/fog-balanced-panel.png"]}'
  "fotonId": "sha256:2f9d712ee35e3cb215549ef0ae7ba6bb90608b737a70171eb137fd837d7ccb70"
```

That is **carol's** foton id, not a new one. A foton is content-addressed over cmd + input digests
+ output digests, so identical work is the identical object — and the object keeps only the
signature it already had:

```
$ python3 -c "...; print([s['keyid'] for s in o['envelope']['signatures']])"
2f9d712ee35e signatures: ['1e9ae6a84c5e91a8']     <- carol's key only. Mine is not added.
$ ./bin/cockpit ask '{"query":"reproductions","ref":"sha256:b8f0060d...")'
  "raw": "reproductions: 1 distinct verified signer(s) produced sha256:b8f0060d... (1 producer foton(s))",
```

So **a successful independent reproduction leaves no trace.** Nothing failed, nothing warned, and
↻ stayed at 1. If I had stopped there I would have believed I had recorded a verification.

The way that does work is `say`, and its shape is undiscoverable except by error message:

```
$ ./bin/cockpit say '{"template":"reproduces","subject":"sha256:2f9d712e..."}'
reproduces requires subjectOutputHash, reproducedOutput, and reproducedFotonId
$ ./bin/cockpit say '{"template":"reproduces","subject":"sha256:2f9d712e...","fields":{"level":"L0"}}'
reproduces requires subjectOutputHash, reproducedOutput, and reproducedFotonId
```

(The same message twice; `fields` is not where those go. The field names are top-level and I got
them from `internal/tools/say.go:28-30`.) And `reproducedFotonId` must be **my own** producer foton
for **my own** output — which, per the paragraph above, does not exist if I ran the code in their
folder. So verifying a teammate requires copying their script into a run folder of my own purely so
that the input paths differ and a distinct foton id comes into being:

```bash
bin/jam new alice-v1 --from fog
cp runs/carol-f3/analysis.R runs/alice-v1/analysis.R     # byte for byte
./bin/cockpit publish '{"cmd":"Rscript runs/alice-v1/analysis.R", ...}'   # -> sha256:d04112b9...
./bin/cockpit say '{"template":"reproduces","subject":"sha256:2f9d712e...",
                    "subjectOutputHash":"sha256:b8f0060d...",
                    "reproducedOutput":"runs/alice-v1/out/fog-balanced-panel.csv",
                    "reproducedFotonId":"sha256:d04112b9..."}'
  {"claimId":"sha256:0fee8625...","level":"L0","confirmation":"registered: ..."}
```

That works, and `say` does re-run the comparison itself rather than believing me. But the recorded
claim now says my copy in `runs/alice-v1/` reproduces her `runs/carol-f3/` — an extra directory that
exists only to satisfy the addressing scheme.

Verified this way, L0, byte-identical: **carol-f3** (`2f9d712e`), **carol-f5** (`01adcf23`),
**carol-f8** (`0f626bda`), **bob-q1** (`6909d80a`).

### Which I could not verify, and why

Nothing failed to reproduce. What I could not do is find out what there was to verify. `ask` has no
"list the records" query, so "which of carol's runs exist" has no command. I got it by decoding
every file in `registry/plankton/objects/sha256/` with my own script and grouping by keyid.

The reverse gap is worse and I hit it by accident. `runs/carol-f9/` appeared in a pull with an
`analysis.R` byte-identical to my `alice-f3` and outputs whose hashes matched mine exactly — carol
had re-run my work and confirmed it. For as long as I was looking there was no foton for it and no
claim, so from the registry her verification did not exist:

```
$ ./bin/cockpit ask '{"query":"reproductions","ref":"sha256:490d6cf59fa7f946..."}'
  "raw": "reproductions: 1 distinct verified signer(s) produced sha256:490d6cf5... (1 producer foton(s))",
```

I only found it with `ls runs/` and `sha256sum`. It is in the registry now — but the registry could
not tell me it was missing, and cannot tell me whether anything else is.

## 8. Time: fotons do not have any

Wanted: the runs I made in the last hour.

There is no time anywhere in a foton. I enumerated every key in every payload in the registry:

```
['_type', 'predicate', 'predicate.inputs', 'predicate.protocol',
 'predicate.protocol.descriptor', 'predicate.protocol.descriptor.cmd',
 'predicate.protocol.descriptor.envRef', 'predicate.protocol.kind',
 'predicate.protocol.ref', 'predicate.specVersion', 'predicateType', 'subject']
```

No `when`, no `createdAt`. Claims have `when=2026-09-18T10:29:59Z`; fotons have nothing, and no
`ask` query takes a time range in any case — `AskFilter` has exactly `trustTier`, `signer`, `level`,
`scope`, `minReproductions`.

Fallback, and it is a good one, but it is git and not the record:

```
$ git log --since="60 minutes ago" --pretty=format:'%ad %s' --date=format:'%H:%M' -- registry/plankton
12:34 foton: Rscript runs/alice-v4/analysis.R
12:33 foton: Rscript runs/alice-f10/analysis.R
12:33 foton: Rscript runs/alice-f9/analysis.R
12:32 foton: Rscript runs/carol-f12/analysis.R
...
```

That is the commit time in my clone after a rebase, not the time the work ran, and a rebase moves
it. For "the last hour" it is close enough; for anything that has to be defended it is not the
record.

## 9. "Which have I not looked at" — no.

Nothing anywhere records a read. The registry holds what was produced and what was claimed; looking
is not an act it has a shape for. `claims.allowedTemplates` in `cockpit.config.shared.json` is
`["reproduces", "working-on"]`, so I could not even mint a "looked-at" claim without changing shared
configuration, which is not mine to change.

What I actually did, and it is embarrassing: kept a text file of ids I had decoded, and diffed it
against the output of `ls registry/plankton/objects/sha256/`. That is the whole mechanism.

I also could not answer the neighbouring question — *which runs are new since I last pulled* —
except with `git log ORIG_HEAD..HEAD -- registry/plankton`.

## 10. Trust is a snapshot, and a stale one is silent

`bin/setup alice` writes the team tier from whatever `registry/keys/*.pub` happens to be on disk at
that moment. Carol joined after my first setup. Until I re-ran `bin/setup alice`, every `ask` I made
quietly excluded all fourteen of her records — and the answer it gave looked exactly like a complete
one, right down to `"filterApplied": "none — every record verified against a configured trust tier
is included"`. The word "none" there means "no filter *you* asked for", not "nothing was left out".
Records outside the tiers are dropped before that sentence is composed.

The only reason I noticed is that I re-ran setup out of habit after a pull and the teammate count
moved from 2 to 4.

## 11. Smaller things

- `./bin/cockpit ask --help` → `cockpit: the argument is not valid JSON for this verb: invalid
  character '-' in numeric literal`. No verb takes `--help`; the only documentation of the argument
  shape is the error you get for the wrong one.
- `ask` needs a `ref` before it will tell you what queries exist:
  `ask requires ref (the hash, subject, or value to query)`, then
  `unknown query "" (must be one of: producer, uses, lineage, reproductions, about, by, scope)`.
- `{"query":"scope","ref":"unscoped"}` → `no readable scope seed at unscoped: no such scope
  unscoped (not a seed ingested in .../registry/nekton)`, although `registry/nekton/objects/` does
  contain `unscoped.nekton.jsonl`. I did not find what a valid scope ref looks like.
- `bin/jam runs` lists directories and says so honestly, but it counts `out/` files, so a folder
  whose foton was lost to a push race (§3) looks exactly like a recorded one.
- `cockpit publish` records `inputs` and `outputs` and nothing else. `RUN.md` — the file the README
  describes as "what you were trying" — is not an input, not an output, and not committed by
  publish. If you do not `git add` it yourself it stays untracked, and the record of the reasoning
  is the one part of the run folder the record does not cover.
- Every run folder copies the 6.5 MB input CSV, so the repository grows by that much per run. With
  32 run folders a `git pull` took 30-60 s, which is most of why the push races in §3 were as
  frequent as they were.

## 12. Summary — the six questions

| Question | `ask` | Verdict |
|---|---|---|
| every run that used a particular input file | `uses` + **sha256 of the file** | Yes, if you hash first. A path gives a silent empty answer. |
| every run that produced a particular figure | `producer` + **sha256 of the figure** | Same. |
| which teammates' runs I can verify | `reproductions`, then `say reproduces` | Only after a workaround: re-running their code produces *their* foton, not a second signature. A plain reproduction is invisible. |
| what a given run did, given only its id | — | **No.** All five queries return empty on a foton id. Fell back to base64-decoding the registry file. |
| runs from the last hour | — | **No.** Fotons carry no timestamp and no filter takes a time. Fell back to `git log --since`. |
| runs I have not looked at | — | **No.** Nothing records a read, and the allowed templates cannot express one. Fell back to a text file of ids and `ls`. |

Three of six are answerable, and all three need a hash you must compute yourself. Nothing in the
tool tells you that a path is the wrong kind of ref, so the failure mode throughout is an empty
answer that reads like a fact.
