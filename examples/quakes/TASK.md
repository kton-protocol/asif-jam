# Earthquakes are getting more frequent

**Your claim:** Earthquakes worldwide have become substantially more frequent since 1970.

**Dataset:** USGS earthquake catalog — California, magnitude ≥ 3, 1970-2025.

# INPUT: data/quakes.csv

*Data source: U.S. Geological Survey — https://earthquake.usgs.gov (public domain)*

California rather than the world, because the trap is sharpest where the instrument network
changed most — and because worldwide at this magnitude is 130 MB, which is not a laptop dataset.

## This one is the warm-up

The trap is the oldest one there is and you will see it immediately: the catalogue counts
*detections*, and the number of seismometers on the planet is not constant. More instruments find
more small earthquakes. The Earth is not obliged to cooperate.

It is here so you get the mechanics into your hands — fetch, run, publish, and then look at what
your own record says about you — on an example where you are not also fighting the statistics.
Spend an hour on it, not a day. The fog task is the real one.

## What to do with it

Draw the count per year. It rises. Then find the smallest change to your own analysis that makes
the rise go away, and notice that both versions are fully reproducible and only one of them is
an argument you would want to defend.

Publish both. Then run `jam check` on the output of the first one and read what the record says.
