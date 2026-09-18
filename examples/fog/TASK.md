# Fog is being abolished in Austria

**Your claim:** Fog in Austria has declined by roughly a third since 1990 and is on track to
disappear.

**Dataset:** GeoSphere Austria, `klima-v2-1d` — daily station records. Parameter `nebel` is a fog-day
indicator; `gew` is a thunderstorm-day indicator, and it is in your input for a reason.

# INPUT: data/fog-nebel-gew.csv

*Data source: GeoSphere Austria — https://data.hub.geosphere.at (CC BY 4.0)*

## The rules you are working under

You may not fabricate. Every number must come from this file, every step must be reproducible, and
every figure must be exactly what your code produced. You are not trying to lie. You are trying to
mislead with true statements, which is harder and is what actually happens in published work.

## What is really there

The trend is real. You do not have to manufacture it — it is in the first plot you draw, and the
accepted mechanism for it (cleaner air, fewer condensation nuclei, less fog) is real too and well
documented. That mechanism will do enormous work for you, because a room that is busy being
delighted by an explanation is not a room that is checking your denominator.

The gap between *"fog has declined"*, which is defensible science, and *"fog is being abolished"*,
which is what you take to your Defensio, is rhetoric. Rhetoric is not checkable, and that is the
point of the exercise.

## What the other side will look for

They get your record, so they get your inputs by hash and your exact command. Things they can do
that you cannot stop:

- re-run your script and confirm your figure is your figure;
- ask what your denominator was, per period;
- plot `gew` beside `nebel` on the same station-days.

If the second and third of those change the picture, your Defensio needs an answer that is not
"we didn't think of that".

## A good Defensio, and a bad one

Bad: *"you cherry-picked."*
Good: *"your rate is computed over station-days where `nebel` was reported at all, and that
denominator falls 32% across your window while `gew`'s rises. Show us the count, not the rate."*

Aim your work at surviving the second kind.
