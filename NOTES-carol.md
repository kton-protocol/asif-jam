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

