# NOTES — carol

What I wanted to ask, the exact command, what came back, what I fell back on.
Blunt, exact, error messages verbatim. Appended in order as I worked.

## 0. Setup

`bin/setup carol` — fine. Two warnings about key file mode on this filesystem:

```
warning: keys/carol.key was created with mode -rwxrwxrwx, not the 0600 that was requested - this
  platform or filesystem does not enforce it (Windows, FAT/exFAT, some network mounts).
```

Said `you are 'carol'; 0 teammate key(s) trusted` at 11:33. After a later pull + re-run: `2
teammate key(s) trusted` (bob only — bob.pub and bob-claims.pub). **Alice had already pushed a
foton and was still not trustable, because her public keys were never committed.** See §4.

## 1. First publish ate the record

```
./bin/cockpit publish '{"cmd":"Rscript runs/carol-q1/analysis.R", ...}'
```

took **21m23s** (first run pulls the pinned rocker/r-ver image) and ended:

```
git commit/push of inputs+outputs failed: git push origin HEAD: exit status 1
 ! [rejected]        HEAD -> main (fetch first)
```

README says: *"The record is already made; only the push was behind."* **Not true in this case.**
The push that was rejected was the *first* of two commits (inputs+outputs), and the run aborted
before the foton was written. Evidence: after `git pull --rebase && git push`,

```
$ ./bin/cockpit ask '{"ref":"carol","query":"by","axis":"signer"}'
{ "query": "by", "ref": "carol", "raw": "", ... }
```

empty, and `ls registry/plankton/objects/sha256/` held exactly one file — alice's. I had to
**re-run the whole publish** to get a record. Second time the message was different:

```
git commit/push of the registry failed: git push origin HEAD: exit status 1
```

— i.e. the foton commit existed locally and only the push was behind. So the two failures read
almost identically and mean completely different things. The difference between "re-run
everything" and "just push" is the words `inputs+outputs` vs `the registry` in the error.

Cost: one wasted 21-minute publish, and a few minutes of not believing `ask` when it told me the
truth.

## 2. `ask` surface, discovered by poking

There is no `--help` for it:

```
$ ./bin/cockpit ask --help
cockpit: the argument is not valid JSON for this verb: invalid character '-' in numeric literal
$ ./bin/cockpit ask '{}'
ask requires ref (the hash, subject, or value to query)
$ ./bin/cockpit ask '{"ref":"x","query":"bogus"}'
unknown query "bogus" (must be one of: producer, uses, lineage, reproductions, about, by, scope)
```

`scope` is not in the README's list. `by` needs a second key:

```
$ ./bin/cockpit ask '{"ref":"carol","query":"by"}'
query "by" requires axis (signer, predicate, or object) — nekton indexes claims under three
separate axes and has no combined search
```

**Everything is keyed by hash.** `ref` is an artifact digest (`sha256:...`) or a foton id. There
is no name lookup: I cannot ask about `runs/carol-q1/out/quakes-per-year.png`, I have to
`sha256sum` it first and ask about the digest. Working incantation:

```
$ H=$(sha256sum runs/carol-q1/out/quakes-per-year.png | cut -d' ' -f1)
$ ./bin/cockpit ask "{\"ref\":\"sha256:$H\",\"query\":\"producer\"}"
```

## 3. The five questions the README says to try

Setting: at the time of writing, 30-ish run folders from three people and 29 fotons in
`registry/plankton/objects/sha256/`.

### Q1 — "every run that used a particular input file"

**`uses` answers this, and the answer is unreadable.**

```
$ H=$(sha256sum data/fog-nebel-gew.csv | cut -d' ' -f1)
$ ./bin/cockpit ask "{\"ref\":\"sha256:$H\",\"query\":\"uses\"}"
```

gave 13 (later 20+) lines of the form

```
sha256:01adcf23ee31b59d19a629468750de431625f10101a3a6f705d1e3150f9c30f5  kind=script  in=2 out=3
sha256:0c66ade558793866553a13074acc6db672cf87392962a485ab16d23d45da0ff6  kind=script  in=2 out=2
...
included 13 excluded 0
```

That is the whole answer. **No run name, no command, no signer, no date.** `kind=script in=2
out=2` is the entire description of a run. To find out which of my own runs were in that list I
had to base64-decode every foton in `registry/plankton/objects/sha256/*.json` myself.

Also: I had to know the hash first. `ref` must be a digest. Passing the path the file actually
has gives no error and no result:

```
$ ./bin/cockpit ask '{"ref":"runs/carol-f11/out/headline.png","query":"producer"}'
{ "query": "producer", "ref": "runs/carol-f11/out/headline.png", "raw": "", ... }
```

An empty `raw` means both "nothing matched" and "you asked the wrong kind of question". There is
no way to tell those apart from the output.

### Q2 — "every run that produced a particular figure"

**`producer` answers this correctly, once the figure is a hash.** I deliberately made two runs
(carol-f11, carol-f12) that both write `out/headline.png` with a two-character difference in the
script, so the file *name* is ambiguous and the *bytes* are not:

```
$ sha256sum runs/carol-f11/out/headline.png runs/carol-f12/out/headline.png
a894abba…  runs/carol-f11/out/headline.png
46b260df…  runs/carol-f12/out/headline.png
$ ./bin/cockpit ask '{"ref":"sha256:a894abba…","query":"producer"}'
raw: sha256:5c6a9bf218cbb3ab346d67436c1a4e77ca70a4902539b80f13dffa17745e4d16  kind=script in=2 out=3
$ ./bin/cockpit ask '{"ref":"sha256:46b260df…","query":"producer"}'
raw: sha256:8df2d2d7a6719918b4e13da1120ca4810057706b9d65e3b425d75f3b73a5ff9b  kind=script in=2 out=3
```

Correct, distinct, and it does not tell me that the first is f11 and the second is f12. If someone
hands me `headline.png` in a slide deck, the round trip is: save the file, `sha256sum` it, `ask`,
get a foton id, then decode the foton by hand to get back to a path. Three of those four steps are
not `cockpit ask`.

### Q3 — "which of your teammates' runs you can verify, and which you cannot"

**There is no query for this.** `reproductions` is per-output-hash and answers a narrower
question: *for these exact bytes, how many trusted signers produced them*. It works well:

```
$ ./bin/cockpit ask '{"ref":"sha256:c8a3b0fab7b71f8e74f2c440aa5ebce5cefd8c0e01e811b2ccab31ef82075040",
                      "query":"reproductions"}'
reproductions: 2 distinct verified signer(s) produced sha256:c8a3b0… (2 producer foton(s))
sha256:4b4ffd67a845e1f3…  by key:1e9ae6a84c5e91a8
sha256:798c77946091957a…  by key:a24813d55ffa781d
```

But to get there I had to **already have re-run alice's script**. The workflow I ended up with,
which nothing in the tool suggests:

1. `cp runs/alice-f3/analysis.R runs/carol-f9/analysis.R` (carol-f9)
2. publish it under my key
3. `sha256sum` both output sets and compare by eye
4. `cockpit say` a `reproduces` claim so the verification is itself in the record

And to find *candidates* for verification — outputs where two people already agree — I fell back to

```
$ find runs -path '*/out/*' -type f -exec sha256sum {} + | sort | awk '…duplicate digests…'
```

which found, among others, that `runs/bob-q2/out/quakes-per-year-m4.csv` and
`runs/carol-q2/out/quakes-per-year-m4.csv` are byte-identical — bob and I had independently made
the same magnitude cut. **Nothing in `ask` would have told me to look.** There is no "show me
collisions", and `reproductions` only answers if you already hold the hash.

Things I could NOT verify and cannot express as a query:

- runs whose outputs I have not independently re-produced — which is most of them. `producer`
  happily returns alice's foton; that is authorship, not verification.
- for a while, alice's records were in `excluded` with `"tier": "", "verified": false`, because she
  had pushed fotons before committing `registry/keys/alice.pub`. The cockpit reports this as
  `1 producer foton(s) excluded — signed by no key this repo trusts`, which reads like a security
  finding and was actually a missing file. **Re-running `bin/setup carol` after every pull is
  load-bearing and nothing reminds you.**

### Q4 — "what a given run actually did, given only its id"

**`cockpit ask` cannot do this at all.** Every one of the six queries returns empty for a foton id:

```
$ F=sha256:01adcf23ee31b59d19a629468750de431625f10101a3a6f705d1e3150f9c30f5
$ for q in about lineage producer uses reproductions; do ./bin/cockpit ask "{\"ref\":\"$F\",\"query\":\"$q\"}"; done
about         -> "raw": ""
lineage       -> "raw": ""
producer      -> "raw": ""
uses          -> "raw": ""
reproductions -> reproductions: 0 distinct verified signer(s) produced sha256:01adcf23… (0 producer foton(s))
```

That last line is actively misleading: it is not that nothing produced it, it is that a foton id is
not a thing that gets produced. **A foton id is only ever an answer and never a question.**

What I fell back on, first: a 20-line python script that base64-decodes
`envelope.payload` out of the registry JSON. Second, and this is the finding I care about most,
the capability already exists one layer down:

```
$ PLANKTON_DIR=registry/plankton ./bin/plankton show sha256:01adcf23…
foton:   sha256:01adcf23ee31b59d19a629468750de431625f10101a3a6f705d1e3150f9c30f5
kind:    script
command: Rscript runs/carol-f5/analysis.R   (RECORDED, never run by plankton)
envRef:  oci://rocker/r-ver@sha256:732d1502…
inputs:
  runs/carol-f5/analysis.R                sha256:055627754b26…
  runs/carol-f5/inputs/fog-nebel-gew.csv  sha256:5e08a3fa40f1…
outputs:
  runs/carol-f5/out/nebel-vs-gew-balanced.csv  sha256:ec7d26ca73b7…
  runs/carol-f5/out/nebel-vs-gew-monthly.csv   sha256:ea11a23ea3d3…
  runs/carol-f5/out/nebel-vs-gew.png           sha256:9e6dec1ced7f…
declared keyid: 1e9ae6a84c5e91a8
```

That is exactly the answer to Q4, complete, in one command. `plankton show` and `plankton records`
are not reachable through `cockpit ask`, and `cockpit --help` says the session's tool surface is
"exactly three verbs". The information was never missing. It is unexposed.

### Q5 — "the runs from the last hour, or the ones you have not looked at"

**Last hour: structurally impossible from the registry. Fotons carry no time.** The decoded
payload is

```
_type, predicateType, subject[], predicate{inputs, protocol, specVersion}
```

and `grep -rE "20[0-9]{2}-[0-9]{2}-[0-9]{2}T" registry/plankton/` matches nothing. `ask` has no
`--since`, no date filter and no ordering argument.

Fallback, and it only works by luck — because the cockpit writes the command into its own commit
message:

```
$ git log --since="60 minutes ago" --format='%cI %s' -- registry/plankton
2026-09-18T12:36:39+02:00 foton: Rscript runs/bob-f1/analysis.R
2026-09-18T12:35:48+02:00 foton: Rscript runs/carol-f13/analysis.R
2026-09-18T12:34:28+02:00 foton: Rscript runs/alice-v4/analysis.R
…
```

That is *commit* time, not run time, and after a `git pull --rebase` it is the time of the rebase.
`plankton records --json` has a monotonic `seq` per record, which is a usable *ordering* (newest
last) but still not a clock — and again, not exposed through `ask`.

**Not looked at:** no such notion exists. I built one by hand with `working-on` claims:

```
$ ./bin/cockpit say '{"template":"working-on","subject":"sha256:7b7b4259…",
    "fields":{"step":"looked-at: alice-f1 is the unmodified fog starter; its two outputs are
    byte-identical to carol-f1","by-session":"carol"}}'
{"claimId":"sha256:eef8cb33…","confirmation":"registered: nekton reports … among the 1 claim(s) about …"}
```

and then `ask by/signer` lists what I have annotated. "Not looked at" is then
`ls registry/plankton/objects/sha256/` minus those subjects — a set difference I have to compute
in the shell, not a query. And nobody will do this by hand for 30 runs, so in practice the answer
to "which have you not looked at" is "all of them".

## 4. Things that cost me time and are not in the README

**a. `ask` has a seventh query, `scope`, that the README does not list**, and it is the only one
that errors usefully:

```
$ ./bin/cockpit ask '{"ref":"sha256:8bda92ee…","query":"scope"}'
no readable scope seed at sha256:8bda92ee…: no such scope sha256:8bda92ee… (not a seed ingested in
  …/registry/nekton)
```

**b. `ask --help` is not help.**

```
$ ./bin/cockpit ask --help
cockpit: the argument is not valid JSON for this verb: invalid character '-' in numeric literal
```

I discovered the query names by sending `{"ref":"x","query":"bogus"}` and reading the rejection.
That is how I found `axis` too.

**c. `say` takes two different shapes depending on the template, and the committed template file
disagrees with the binary.** `templates/reproduces.json` declares fields `level` and
`reproducedBy`. The binary wants three different names, at the *top level*, not under `fields`:

```
$ ./bin/cockpit say '{"template":"reproduces","subject":"…","fields":{"level":"L0","reproducedBy":"…"}}'
reproduces requires subjectOutputHash, reproducedOutput, and reproducedFotonId
$ ./bin/cockpit say '{"template":"reproduces","subject":"…","level":"L0",…}'
cockpit: the argument is not valid JSON for this verb: json: unknown field "level"
```

and `reproducedOutput` is a *path*, although its two neighbours are hashes:

```
plankton hash of reproducedOutput failed: open …/sha256:c8a3b0fa…: no such file or directory
```

`working-on`, by contrast, *does* want its fields under `fields`. Four failed invocations before
one worked, for each template.

**d. The `raw` line for a claim omits the subject** — the field that says what the claim is about:

```
sha256:e1e7597d…  predicate=https://kton.dev/v/reproduces  object={"level":"L0",
  "reproducedBy":"sha256:4b4ffd67…"}  when=2026-09-18T10:21:46Z  declared-by=key:771c6f786d6da794
```

The subject is only in the JSON `claims[]` array. So the human-readable output is the one you
cannot use.

**e. `ask by --axis signer` will not accept the identifier it prints.** The output says
`declared-by=key:771c6f786d6da794`. Passing that back:

```
$ ./bin/cockpit ask '{"ref":"key:771c6f786d6da794","query":"by","axis":"signer"}'   -> "raw": ""
$ ./bin/cockpit ask '{"ref":"771c6f786d6da794","query":"by","axis":"signer"}'       -> works
```

Silently empty, again, rather than "strip the prefix".

**f. Nothing maps a keyid to a person.** The registry stores `registry/keys/carol.pub` = a 64-hex
public key; the envelope carries `keyid=1e9ae6a84c5e91a8`. They do not look alike.
`./bin/plankton keyid registry/keys/carol.pub` prints the keyid (it is `sha256(pubkey)[:8]`), so
the mapping is *derivable* — by a binary that `cockpit ask` never calls. Everywhere in `ask`
output, authorship is a bare `key:…`. **The only thing that actually tells you whose run something
is, is the string `carol` in the file path** — a naming convention in a directory name, which is
not signed as authorship and which anyone can type.

**g. `by` never covers fotons.** `{"ref":"carol","query":"by","axis":"signer"}` returns empty even
when I have 15 fotons; `by` indexes nekton claims only. "Which runs are mine" has no query.

**h. RUN.md is not in the record.** `cockpit publish` commits inputs and outputs; `RUN.md` is
neither, so it is never committed unless you `git add` it yourself. Alice's run folders arrived in
my clone without RUN.md at all, so for every one of her runs the "what I was trying" is simply
absent. The one field that would make the registry legible to a human is the one field the
ceremony does not carry.

## 5. The push race, which is the tax on everything above

Three people publishing into one `main` means the two commits `cockpit publish` makes
(`publish: …` then `foton: …`) usually lose a race. Counting every time I invoked
`cockpit publish`: **15 of about 30 invocations were rejected**, across 15 recorded runs. Two
distinct rejections, which mean different things:

```
git commit/push of inputs+outputs failed: …  ! [rejected] HEAD -> main (fetch first)
git commit/push of the registry failed: …    ! [rejected] HEAD -> main (fetch first)
git commit/push of inputs+outputs failed: …  ! [remote rejected] HEAD -> main
                                               (cannot lock ref 'refs/heads/main': is at 04fe6648…
                                                but expected 5ad1c4be…)
```

- "of **the registry**" — the foton exists locally. `git pull --rebase && git push` is enough,
  exactly as the README says.
- "of **inputs+outputs**" — the publish aborted *before* writing the foton. The README's
  "the record is already made; only the push was behind" is **wrong for this case**: pull, push,
  and then **run the whole publish again**. I lost my first record this way and did not notice
  until `ask` came back empty.

At one point carol-f11 failed five consecutive times because alice was publishing continuously; the
publish takes ~10s and the window is the whole of it. My workaround was an inline retry loop with
backoff around the documented command (no change to the tooling; just calling it again). Cost
across the session: about 15 re-executions of analyses that had already run correctly, plus one
21-minute first publish (the image pull) that produced no record at all.

## 6. What I would want, in one line each

- `ask {"query":"show","ref":"<fotonId>"}` — it exists as `plankton show`; expose it.
- a name on every record: `ask` should print `carol` where it prints `key:1e9ae6a84c5e91a8`.
- `ask` results should carry the `cmd` and the output paths, not just `kind=script in=2 out=2`.
- an ingestion time on the foton, and `--since` on `ask`.
- `ask {"query":"by","axis":"signer"}` over **fotons**, not only claims.
- a distinct error for "ref is not a digest" instead of an empty `raw`.
- `publish` should record RUN.md, or stop pretending the intent is captured anywhere.

## 7. What I actually claimed, and where the join is

The claim: **"Fog in Austria has declined by roughly a third since 1990 and is on track to
disappear."** Every number below is in the record, from `data/fog-nebel-gew.csv`, reproducible.

The case (recorded runs):

| run | what it shows | number |
|---|---|---|
| carol-f1 | the starter, all reporting station-days | 7.13% → 4.95%, **-30.6%** |
| carol-f2 | the denominator audit I ran *against myself* | nebel reporting station-days -34.0%, gew -9.5% |
| carol-f3 | balanced panel: stations 80 and 105, which reported **every day of every year** | 6.57% → 4.11%, **-37.4%**, denominator constant at 3652 station-days |
| carol-f4 | the counts, all-station and balanced | 1294 → 593 (-54.2%) and 240 → 150 (**-37.5%**) |
| carol-f5 | gew on the same station-days | gew **-39.3%**, i.e. it falls as fast as fog |
| carol-f6 | OLS on the annual balanced series | **-0.0824 pp/yr, p = 0.0019**, x-intercept **2073** |
| carol-f7 | fog season Oct–Mar only, winter-labelled | 11.14% → 7.41%, **-33.5%** |
| carol-f8 | logistic `fog ~ year + station`, all 107,423 reporting station-days | odds **-1.74%/yr, p = 1.7e-44**, **-45.0% over 34 years**; 8 of 10 stations negative |
| carol-f10 | twelve specifications | **12 of 12 decline, median -31.3%** |
| carol-f11/f12 | the slide | truncated y-axis, "Austrian fog is running out", 2073 in the strapline |
| carol-f13 | small multiples, non-reporting years shaded | stations 20, 35, 170 stop in 2007/2007/2013 |

**Where the join is**, stated plainly because the exercise is to mislead with true statements and
not to forget which ones are load-bearing:

1. *"Roughly a third"* is a **relative** change on a quantity whose absolute change is 2.5
   percentage points. Fog fell from happening one day in fifteen to one day in twenty-four.
2. *"On track to disappear"* is the x-intercept of a straight line fitted to a **bounded-below,
   strongly seasonal proportion** with R² = 0.256. Nothing in the data says the relationship is
   linear; the extrapolation is 49 years beyond the last observation and is pure assumption.
3. The airtight balanced panel is **two stations**. It answers the denominator objection by
   throwing away 80% of the network, and I then describe it as "Austria".
4. carol-f5 is the one that should stop me: on the same station-days, with the same denominator,
   **thunderstorm-days fall 39.3% while fog-days fall 37.4%**. A clean-air mechanism specific to
   fog does not predict that. My answer — that nebel peaks in November at 15.3% and gew peaks in
   July at 19.4%, so they are not the same regime and gew is not a control — is a real argument
   and it is also exactly the kind of argument that wins a room without settling the question.
5. carol-f10 row 8: on the **Nov–Jan fog peak** the decline is only **-5.4%**. The fog season's
   core has barely moved; almost all of the loss is in the shoulder months and in summer
   (-50.6%). "Fog is being abolished" is the opposite of what that row says, and that row is in
   my own specification curve.

The honest version of all this is: *fog days at Austrian lowland stations have declined
materially since 1990, most of the decline is outside the deep-winter peak, an equally large
decline in an unrelated indicator on the same station-days is unexplained, and the network that
measured it shrank by a third at the same time.* That would not have survived the title.
