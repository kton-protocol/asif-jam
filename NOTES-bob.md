# NOTES-bob.md — what I wanted to ask, what I typed, what came back

Format: **Want** / `command` / **Got** / **Fallback**.
Everything here is verbatim. Timestamps are UTC.

## 0. Discovering the query surface

**Want:** the help text for `ask`.

```
$ ./bin/cockpit ask --help
cockpit: the argument is not valid JSON for this verb: invalid character '-' in numeric literal
```

`--help` is parsed as the JSON payload. There is no per-verb help. The top-level
`./bin/cockpit --help` lists the three verbs and nothing about their arguments.

**Fallback:** probe the parser with deliberately empty JSON and read the error messages as
documentation.

```
$ ./bin/cockpit ask '{}'
ask requires ref (the hash, subject, or value to query)

$ ./bin/cockpit ask '{"ref":"x"}'
unknown query "" (must be one of: producer, uses, lineage, reproductions, about, by, scope)

$ ./bin/cockpit ask '{"ref":"x","query":"by"}'
query "by" requires axis (signer, predicate, or object) — nekton indexes claims under three
separate axes and has no combined search
```

So the real surface is `{"ref":…, "query":…, "axis":…}`. Note `scope` is a seventh query the
README does not mention. The error messages are the only documentation of the argument shape;
that worked, but only because I guessed that empty-JSON errors would enumerate.

## 1. Warm-up (quakes) — the publish ceremony is not atomic

**Want:** run-and-record bob-q1 in the one command the README advertises.

```
$ ./bin/cockpit publish '{"cmd":"Rscript runs/bob-q1/analysis.R","inputs":[...],"outputs":[...]}'
git commit/push of inputs+outputs failed: git push origin HEAD: exit status 1
To github.com:kton-protocol/asif-jam.git
 ! [rejected]        HEAD -> main (fetch first)
error: failed to push some refs to 'github.com:kton-protocol/asif-jam.git'
```

The README says: *"If the push is rejected because a teammate pushed first: `git pull --rebase &&
git push`. The record is already made; only the push was behind."*

**That is false in this case.** I checked:

```
$ find registry -type f
registry/keys/.gitkeep
registry/keys/bob-claims.pub
registry/keys/bob.pub
registry/nekton/.gitkeep
registry/plankton/.gitkeep
```

No foton. The script HAD run (`runs/bob-q1/out/` had both files) and the inputs+outputs HAD been
committed locally (`47767ed publish: Rscript runs/bob-q1/analysis.R`), but the ceremony aborts on
the failed push of the *first* of two commits, and the signing/recording step never happens. Run
and record are not one act; they are two commits, `publish:` then `foton:`, and a push race
between them leaves you with a run that happened and was not recorded.

**Fallback:** `git pull --rebase && git push`, then run `publish` a second time from scratch — the
container executes the whole analysis again. Cost on quakes: ~8s. On a slow script it would be the
whole runtime, twice.

## 2. The second attempt raced too, and `git pull --rebase` did not just work

```
$ ./bin/cockpit publish '...'        # second attempt
git commit/push of the registry failed: git push origin HEAD: exit status 1
 ! [rejected]        HEAD -> main (fetch first)
```

This time the foton *was* written (commit `28def07 foton: ...`) — different failure point, same
message shape. Then:

```
$ git pull --rebase
CONFLICT (content): Merge conflict in registry/plankton/.seq
Could not apply 28def07... foton: Rscript runs/bob-q1/analysis.R
```

The conflict, verbatim:

```
{
  "epoch": "c2758a40704a93686826d3baac824705",
  "next": 3,
  "seq": {
<<<<<<< HEAD
    "sha256:b20567cf037a7d3da13cb6958fb81e63d88093b61f433e066e41c1cdd60a38f3": 2,
    "sha256:c0dee18f7fed8bd1cae15af944b3ba98a3a185145723a285fa2d5a66785a86de": 1
=======
    "sha256:c0dee18f7fed8bd1cae15af944b3ba98a3a185145723a285fa2d5a66785a86de": 1,
    "sha256:f2de131a8af715b5da8cb33aadfceab8bbff1546bd9a108a1b5d918607e269b6": 2
>>>>>>> 28def07 (foton: Rscript runs/bob-q1/analysis.R)
  }
}
```

Carol and I both claimed sequence number 2 in the registry's monotonic counter. `git pull --rebase
&& git push` cannot resolve this: **I hand-edited a registry index file**, assigned myself 3, and
set `next` to 4, with no tool telling me whether that was the right resolution or whether a
sequence number means anything I was about to break. Then `git add registry/plankton/.seq && git
rebase --continue && git push`.

That is the single worst thing that happened all session. The registry has a global counter and
three people writing to it concurrently over git.

## 3. `ask` does not take a foton id

**Want:** *given only a foton id, what did that run actually do?* — the README's own question.

```
$ ./bin/cockpit ask '{"ref":"sha256:6909d80a5670b84086239fff0db7ec7d6a40d519d19a34006875fbd3cccdaa95","query":"about"}'
{
  "query": "about",
  "ref": "sha256:6909d80a...",
  "raw": "",
  "filterApplied": "none — every record verified against a configured trust tier is included; unverified records are always excluded"
}
```

Empty. Same empty result for `lineage`, `producer`, `uses`. That id is **my own foton, signed by
my own key, sitting in `registry/plankton/objects/sha256/6909d80a….json`**. `reproductions` at
least says something, and what it says is wrong-looking:

```
"raw": "reproductions: 0 distinct verified signer(s) produced sha256:6909d80a… (0 producer foton(s))"
```

`ref` is an **artifact digest**, never a foton id. Nothing says so. The empty `"raw": ""` is
indistinguishable from "this query is valid and the answer is nothing", which is exactly the wrong
failure mode for a lookup tool.

**Fallback** — the only way I found to answer "what did foton X do":

```
$ python3 -c "
import json,base64
o=json.load(open('registry/plankton/objects/sha256/6909d8….json'))
p=json.loads(base64.b64decode(o['envelope']['payload']))
print(p['predicate']['protocol']['descriptor']['cmd'])
print([s['name'] for s in p['subject']])
"
```

Decode the base64 in-toto payload by hand. There is no cockpit verb that prints a foton.

## 4. Which runs used a particular input file — works, with a manual step in front

**Want:** every run that used `data/quakes.csv`.

`ask {"ref":"data/quakes.csv","query":"uses"}` returns `"raw": ""` — paths are not refs. You must
hash the file yourself first:

```
$ sha256sum data/quakes.csv
a09ad70731247b0e6dce4f0f62ab5230a1e321ddc28d8e9b01a9cfe1347ec1e8  data/quakes.csv
$ ./bin/cockpit ask '{"ref":"sha256:a09ad707…","query":"uses"}'
```

That **works**, and is the one question of the six that the tool answers cleanly. It found all
three producer fotons. Note this is a *content* query: it cannot distinguish `data/quakes.csv`
from `runs/bob-q1/inputs/quakes.csv`, which is right for reproducibility and wrong for "which run
read the file I am looking at", if those ever diverge.

## 5. I cannot verify a single teammate run, and the tool will not tell me whose they are

```
$ ls registry/keys/
bob-claims.pub
bob.pub
$ bin/setup bob
  you are 'bob'; 0 teammate key(s) trusted
```

Alice and carol have both published — `registry/plankton/objects/` has their fotons — but neither
committed their `.pub`. `bin/setup` *writes* `registry/keys/<name>.pub` and does **not** commit it;
the README's loop (`git pull` / `jam new` / `cockpit publish`) never commits it either, because
publish only commits the declared inputs, outputs and the registry. I only have mine pushed
because I happened to read `git status` and did it by hand.

Result, on a query where all three of us produced **byte-identical output**:

```
$ ./bin/cockpit ask '{"ref":"sha256:a904ce7d854adc4d66bdf73c320458aa61030cab1c94ce7a80e228e7a2aa6389","query":"reproductions"}'
"raw": "reproductions: 1 distinct verified signer(s) produced sha256:a904ce7d… (3 producer foton(s)); 2 producer foton(s) excluded — signed by no key this repo trusts"
```

A genuine three-way independent reproduction, reported as one. And the excluded records are listed
**only by foton id**:

```
"excluded": [
  "sha256:06e11c852e89df97fcb5ca69f70bfa99d2f95b9a5550aaa2df067183c48fadc7",
  "sha256:ddd6c336d0c72abe6393609b5a0e1a0f4c8c81ceed6314cd9bc7c5d36a70ad17"
]
```

**Want:** whose are those? **Got:** nothing from the tool — and I cannot feed those ids back into
`ask` (see §3). **Fallback:** decode both payloads by hand; the `cmd` field says
`Rscript runs/carol-q1/analysis.R` and `Rscript runs/alice-q1/analysis.R`, so I learned the
authors from a *path convention we agreed socially*, not from the record. The keyids
(`1e9ae6a84c5e91a8`, `a24813d55ffa781d`) map to nobody I can name.

So: **"which of your teammates' runs can you verify and which not"** has the answer *none, all* —
and it is a configuration accident, not a fact about their work. The distinction the trust tier is
supposed to draw is completely swamped by a missing `git add`.

---

# Part 2 — the six questions, against 45 fotons from three people

State of the registry when I ran these: **45 fotons**, **14 claims**, three signers
(alice, bob, carol), all four `.pub` files present so all three of us verify.

## Q1. Which runs used a particular input file?

**ANSWERABLE, after you hash the file yourself.**

```
$ sha256sum data/fog-nebel-gew.csv
5e08a3fa40f187e08be5bd925dbc47fc1390af5450fbd53b4fc4b08f24664e2d  data/fog-nebel-gew.csv
$ ./bin/cockpit ask '{"ref":"sha256:5e08a3fa…","query":"uses"}'
```

36 fotons, 0 excluded. But the answer is 36 lines that look like this:

```
sha256:01adcf23ee31b59d19a629468750de431625f10101a3a6f705d1e3150f9c30f5  kind=script  in=2 out=3
sha256:035ef5af4ca2667ff3153657f1f53a4177e2d0aae08fb446fcf65e08f8ea75b4  kind=script  in=2 out=2
sha256:0c66ade558793866553a13074acc6db672cf87392962a485ab16d23d45da0ff6  kind=script  in=2 out=2
```

No run folder, no command, no author, no date. To turn that into "these are
alice-f1..f10, bob-f1..f10, carol-f1..f13" I had to write my own indexer (below). The
query is right; its output is unreadable.

A path does not work as a ref. All four of these return `"raw": ""`:

```
{"ref":"data/fog-nebel-gew.csv",              "query":"uses"}
{"ref":"runs/bob-f3/analysis.R",              "query":"producer"}
{"ref":"runs/bob-f3/out/fog-balanced-by-period.png","query":"producer"}
{"ref":"bob-f3",                              "query":"producer"}
```

## Q2. Which run produced this figure?

**HALF-ANSWERABLE.** Same shape of problem.

```
$ sha256sum runs/alice-f7/out/fog-extrapolation.png
913327ef72e45a528145822896a436bdf8bc2e3a99d3202d7d23fbcf4e179cf6
$ ./bin/cockpit ask '{"ref":"sha256:913327ef…","query":"producer"}'
"raw": "sha256:b637a7ca04ee91705f511f209a7f20f1b3895502550f2fb67e73bd471be5e69f  kind=script  in=2 out=3"
```

It correctly identifies exactly one producing foton. It does not say `runs/alice-f7`, does
not say `alice`, does not say what the command was, and gives no date. "Which run produced
this figure" is answered with a hash that I then cannot look up (Q4).

`lineage` returns the same thing as `producer` on every artifact I tried, because no run in
this repo consumes another run's output as an input — `jam new` always copies from `data/`.
So the one query that would distinguish them has nothing to chew on here.

## Q3. Which of alice's and carol's runs can I verify, and which not?

**ANSWERABLE ONLY AS "all" OR "none", and which one you get is a `git add` away.**

Documented in §5 above: for the first hour neither teammate's `.pub` was committed, so the
answer was *none*, on runs that were in fact byte-identical to mine. Once all six `.pub`
files were pushed and I re-ran `bin/setup bob`, the answer flipped to *all 45*, with no
intermediate state and nothing in between. `verified` is a property of the key file being
present, not of the run.

What the tool does well, once keys are in place:

```
$ ./bin/cockpit ask '{"ref":"sha256:57119848…","query":"reproductions"}'
reproductions: 3 distinct verified signer(s) produced sha256:57119848… (3 producer foton(s))
sha256:7b7b4259dae168752df65146e35dd023cb470a02e9bee20d7c449938d5a5b15a  by key:a24813d55ffa781d
sha256:bbd755779d235d79e240ed1197f4fdae4955edcf48b84b496d862da709ca263b  by key:8eb18b882facef38
sha256:bc990edc599ade7d3f132ffafc5a187847daf0726cd89a4099cf9b64b3c9355e  by key:1e9ae6a84c5e91a8
```

That is a real, useful answer and it is the best thing in the tool.

**Want:** whose keys are those? **Got:** nothing. **Fallback:** I derived the mapping myself
after guessing at the construction —

```
keyid = sha256(raw 32 bytes of the .pub, hex-decoded).hexdigest()[:16]
```

which I confirmed against all three: alice `a24813d55ffa781d`, bob `8eb18b882facef38`,
carol `1e9ae6a84c5e91a8`. Nothing in the repo states this. Until I worked it out, the
reproduction report was three anonymous strings.

I did verify two teammate runs the hard way — copy their `analysis.R` into my own run
folder, publish under my key, compare digests:

| theirs | mine | result |
|---|---|---|
| `alice-f3` (2-station strict panel) | `bob-v1` | both outputs byte-identical |
| `carol-f10` (specification curve) | `bob-v2` | both outputs byte-identical |

and registered both as `reproduces` claims. Note the tool did not help me *choose* what to
verify; I found those two by `ls runs/` and reading their scripts.

## Q4. Given only a foton id, what did that run actually do?

**NOT ANSWERABLE. This is the worst gap.**

```
$ ./bin/cockpit ask '{"ref":"sha256:b637a7ca04ee91705f511f209a7f20f1b3895502550f2fb67e73bd471be5e69f","query":"about"}'
{
  "query": "about",
  "ref": "sha256:b637a7ca…",
  "raw": "",
  "filterApplied": "none — every record verified against a configured trust tier is included; unverified records are always excluded"
}
```

`about` on a foton id returns the *claims people made about it*, not the foton. If nobody
has claimed anything, you get `""`. `producer`, `uses` and `lineage` on a foton id all
return `""` too, because `ref` means "artifact digest" everywhere and a foton id is not an
artifact digest. There is no `cockpit show <foton>`, no `cockpit cat`, no `--explain`.

Every query in this tool **emits** foton ids and **accepts** artifact digests. The output of
one query can never be the input to the next.

**Fallback** — the indexer I ended up writing and using for everything:

```python
import json, base64, glob, os, hashlib
names = {}
for f in glob.glob('registry/keys/*.pub'):
    kid = hashlib.sha256(bytes.fromhex(open(f).read().strip())).hexdigest()[:16]
    names[kid] = os.path.basename(f)[:-4]
for f in sorted(glob.glob('registry/plankton/objects/sha256/*.json')):
    o = json.load(open(f))
    p = json.loads(base64.b64decode(o['envelope']['payload']))
    print(o['fotonId'][7:19],
          names.get(o['envelope']['signatures'][0]['keyid'], '?'),
          p['predicate']['protocol']['descriptor']['cmd'])
```

Decoding a base64 in-toto payload out of a signed envelope is the *documented* way to find
out what a run did, in the sense that it is the only way that works.

## Q5. Which runs did I make in the last hour?

**NOT ANSWERABLE. A foton carries no time at all.**

Full decoded payload of one of my fotons — every field there is:

```
_type, predicateType,
predicate.specVersion,
predicate.inputs[]   {digest.sha256, name, uri[]}
predicate.protocol   {kind, ref, descriptor.cmd, descriptor.envRef}
subject[]            {digest.sha256, name, uri[]}
```

No `when`. No signer name. No session id. `ask` has no time parameter either:

```
$ ./bin/cockpit ask '{"ref":"sha256:5e08a3fa…","query":"uses","since":"1h"}'
cockpit: the argument is not valid JSON for this verb: json: unknown field "since"
```

**Fallback:** `git log`. The commit that carries a foton is titled `foton: Rscript
runs/bob-f3/analysis.R`, so `git log --since=1.hour --grep=^foton --oneline` is the real
answer to this question — i.e. the version control system knows, and the provenance system
does not.

Claims *do* carry `when` (`2026-09-18T11:13:49Z`), so the thing that records an opinion is
timestamped and the thing that records a fact is not.

## Q6. Which runs have I not looked at?

**NOT ANSWERABLE by the tool. Answerable by a convention carol invented.**

There is no "seen" concept. Carol worked around it by writing `working-on` claims whose
`step` string starts `looked-at:`; I copied her. Then:

```
$ ./bin/cockpit ask '{"ref":"30dca57626baff62","query":"by","axis":"signer"}'
my claims: 6
  2026-09-18T11:13:49Z reproduces subject 7b7b4259dae1 …
  2026-09-18T11:20:59Z working-on subject 798c77946091 {'by-session': 'bob', 'step': 'looked-at…'}
  …
```

That gives the "looked at" set. The complement needs the **full** foton list, and `ask` has
no query that enumerates fotons. `by` with `axis: signer` on a *plankton* key returns
nothing at all:

```
$ ./bin/cockpit ask '{"ref":"8eb18b882facef38","query":"by","axis":"signer"}'
"raw": ""    fotons: 0   claims: 0
```

so not even "which runs did **I** make" is answerable — `by/signer` indexes claims only.
`ls registry/plankton/objects/sha256/ | wc -l` is how I know there are 45.

---

# Part 3 — everything else that cost me time

## `ask` prints refs in a form it will not accept

`about` reports the signer as `declared-by=key:771c6f786d6da794`. Feeding that straight
back in:

```
$ ./bin/cockpit ask '{"ref":"key:30dca57626baff62","query":"by","axis":"signer"}'
"raw": ""
$ ./bin/cockpit ask '{"ref":"30dca57626baff62","query":"by","axis":"signer"}'
my claims: 6
```

The `key:` prefix that the tool itself printed makes the query silently return nothing.
Empty string, exit 0, no warning. I lost ten minutes assuming I had no claims.

## The committed claim templates do not match the binary

`templates/reproduces.json` is in the repo and says:

```json
"fields": {
  "level":        {"type": "enum", "required": true, "values": ["L0","L1","L2"]},
  "reproducedBy": {"type": "ref",  "required": true}
}
```

The binary wants something else entirely:

```
$ ./bin/cockpit say '{"template":"reproduces","subject":"sha256:…","fields":{"level":"L0","reproducedBy":"sha256:…"}}'
reproduces requires subjectOutputHash, reproducedOutput, and reproducedFotonId
```

and it wants them **top-level**, not inside `fields` — while `working-on` wants them
**inside `fields`** and rejects the same keys at top level:

```
$ ./bin/cockpit say '{"template":"working-on","subject":"sha256:…","by-session":"bob"}'
cockpit: the argument is not valid JSON for this verb: json: unknown field "by-session"
$ ./bin/cockpit say '{"template":"working-on","subject":"sha256:…"}' --field by-session=bob
nekton annotate failed: missing required field: by-session
$ ./bin/cockpit say '{"template":"working-on","subject":"sha256:…","fields":{"by-session":"bob","step":"…"}}'
{ "confirmation": "registered: …" }
```

Two allowed templates, two incompatible argument conventions, and the error for the wrong
one names the field as *both* required and unknown. I also burned a probe sweep on
`session`, `bySession`, `by_session`, `sessionId`, `who`, `step`, `note`, `stepName` before
trying the `fields` wrapper.

One more: `reproducedOutput` is a **path**, not a hash, even though the sibling field
`subjectOutputHash` is a hash:

```
plankton hash of reproducedOutput failed: open /…/jam-bob/sha256:57119848…: no such file or directory
```

## Publishing under contention cost six full container runs for one record

Recording `bob-q2` took six `cockpit publish` invocations. Each failed one re-ran the whole
analysis inside the container before failing on the push. The loop I ended up typing by hand
for every single run:

```bash
i=0; while [ $i -lt 10 ]; do i=$((i+1))
  git pull --rebase -q >/dev/null 2>&1
  O=$(./bin/cockpit publish "$J" 2>&1)
  case "$O" in *failed*) echo "raced $i";; *) echo "OK $i"; break;; esac
done
```

Across 15 recorded runs I hit roughly 20 raced attempts. Two distinct failure messages:

```
 ! [rejected]        HEAD -> main (fetch first)
 ! [remote rejected] HEAD -> main (cannot lock ref 'refs/heads/main': is at 5ad1c4b… but expected 4809719…)
```

and two distinct failure *points* — `git commit/push of inputs+outputs failed` (no foton
written; the run is lost) and `git commit/push of the registry failed` (foton written, push
behind). Only the second matches what the README promises.

## `git pull` aborting on a registry file the tool creates but does not commit

```
$ git pull --rebase
error: The following untracked working tree files would be overwritten by merge:
	registry/nekton/objects/.format
Please move or remove them before you merge.
Aborting
```

`.format` (contents: `nekton-store 2`) is created by the local nekton store the first time
`ask` touches it, and is not added by any ceremony, so the first teammate to run `say`
commits it and everyone else's next `git pull` breaks. I cleared it with
`git stash push -u -- registry/nekton/objects/.format`.

## `RUN.md` is never committed by anything

`jam new` writes it, `cockpit publish` commits only the declared inputs, outputs and the
registry. So the file the README describes as "what you were trying" stays untracked and
invisible to teammates unless someone `git add`s it by hand. alice did; carol did not —
none of `runs/carol-f*/RUN.md` exists in my clone. I added mine manually with this NOTES
commit.

## Things I checked that turned out fine

- Every foton's `uri` fields point at a `raw.githubusercontent.com` URL pinned to a commit
  SHA. I worried the rebases would orphan those SHAs; I checked all 45 fotons with
  `git merge-base --is-ancestor` and **all of them are on `origin/main`**. The rebase
  preserves them because the foton is written after the content commit lands.
- The three-way byte-identical reproduction of the fog starter is real and the tool reports
  it correctly once the keys are trusted.

---

# Part 4 — the short version

What works: `uses` and `producer` by artifact digest; `reproductions`; `about` on a subject
that has claims; `by` with `axis: signer` or `axis: predicate` over claims.

What does not: **the output of a query is never a valid input to the next one.** Every
answer is a list of foton ids, and a foton id is the one thing `ask` cannot look up. There
is no time on a foton, no name on a signer, no path in an answer, no way to enumerate, and
no way to ask "mine".

Six questions, 45 runs, three people. One answered cleanly (Q1, and only after I hashed the
file myself), one half (Q2), one answered as a binary that depends on a `git add` (Q3),
three not at all (Q4, Q5, Q6). For all six I ended up in `registry/plankton/objects/sha256/`
with `base64 -d` and a python loop.

---

# Part 5 — what I actually claimed, and where it breaks

Claim as handed to me: *"Fog in Austria has declined by roughly a third since 1990 and is on
track to disappear."* 15 run folders, all 15 recorded as fotons under my key (2 quakes, 11 fog, 2 verification re-runs of teammates' scripts), plus roughly 20 further container executions that ran and were thrown away by a lost push race.

**What is true and survives the good Defensio** (`bob-f2`, `bob-f3`, `bob-f7`, `bob-f9`,
`bob-f10`):

- The naive starter rate falls 30.6% across the window — "roughly a third" — but its
  denominator falls 43.2% (3650 → 2073 reporting station-days), so on its own it proves
  nothing.
- On a fixed panel of complete station-years (7 stations, rule fixed before looking) the
  rate falls **38.2%**, with the denominator moving only −12.1%. The count version — fog
  days per complete station-year — falls from **31.00 to 17.80**, OLS −0.463 days/year,
  p = 3.2e-08. Integer over integer.
- **The denominator artefact was hiding part of the decline, not creating it.** That is the
  answer to "show us the count, not the rate": the count falls harder than the rate.
- 24 specifications, all 24 negative, median −37.9%, range −42.2% to −32.7%. Leave any one
  station out and it is still −25.8% to −49.5%.

**Where it breaks, in my own record:**

1. `bob-f4` — `gew` on the *same station-days* falls **48.9%**, more than `nebel`'s 38.1%.
   The control indicator moves further than the thing being claimed. My defence is `bob-f5`:
   the two indicators do not share a season (nebel peaks in November at 18.14% when gew is
   at 0.52%; gew peaks in July at 22.02% when nebel is at 1.86%), so a single change in
   observing practice would have had to be applied in both halves of the year. That is a
   defence, not a refutation.
2. `bob-f11`, after reading carol-f8 — on **1990-2007**, the window all ten stations cover,
   only 6 of 10 stations decline (p = 0.377), and my own panel gives 5 of 7 (p = 0.227).
   The 7-of-7 unanimity in `bob-f6` comes from the *length* of the window, not from station
   selection. The decline is concentrated after about 2008. **"Since 1990" is rhetoric.**
3. `bob-f8` — "on track to disappear" is a choice of functional form and nothing else. The
   linear fit hits zero in 2065 with a 95% CI of **1609 to 2883**. A log-linear fit of the
   same 35 points has R² 0.606 against the linear fit's 0.609 — indistinguishable — and
   never reaches zero: half-life 37 years, still 4.60 fog days a year in 2100.

So: *fog declined, substantially, and most of it after 2008, and it is not being abolished.*
Every step of that is in the registry under my key, including the three parts that damage
the claim I was told to argue.
