# Fog is being abolished in Austria — the case, and what breaks it

alice. Every number below is produced by a run in this repository, named by its foton id. Nothing
is estimated, adjusted or carried over from anywhere else.

## The case, as I would take it to a Defensio

**GeoSphere `klima-v2-1d`, ten Austrian stations, 131,490 station-days, 1990-2025.**

1. **The headline.** Fog days as a share of the station-days on which fog was reported:
   **7.13% in 1990-1994, 4.95% in 2020-2024 — a decline of 30.6%.** Roughly a third, in one
   generation. `alice-f1`, foton `sha256:7b7b4259dae1`, output `runs/alice-f1/out/fog-by-period.csv`.
   Independently produced byte-for-byte by carol (`sha256:bc990edc599a`); `ask reproductions` on
   that output reports 2 distinct verified signers.

2. **It is not the denominator.** Fix the station set in advance — every station reporting fog on
   ≥350 days in ≥34 of the 36 years (30, 80, 105, 131) — and the decline is not smaller but larger:
   **9.16% → 3.74%, −59%.** `alice-f2`, `sha256:7512767a0c68`.

3. **It is not station turnover at all.** Two stations (80, 105) have an unbroken record in every
   one of the 36 years. On those alone the annual fog rate falls at **−0.0725 percentage points a
   year, p = 0.0045**. `alice-f3`, `sha256:798c77946091`.

4. **It is not one station.** Carol's station-fixed-effects logistic model over all 107,423
   reporting station-days gives a year coefficient of **−0.01758 (p = 1.7 × 10⁻⁴⁴), −45% over 34
   years**, with 8 of 10 stations trending down. `carol-f8`, `sha256:0f626bda22b3` — which I
   reproduced at L0 (`alice-v4`, `sha256:f3daa6fd2341`, claim `sha256:5d261a3908bd`).

5. **The mechanism is known.** Sulphate and particulate emissions fell sharply across Central
   Europe over exactly this window; fewer condensation nuclei, less fog. The decline has a cause,
   and the cause is one we chose.

6. **Extrapolated, it ends.** OLS on the annual rate: **−0.1014 pp/year, R² = 0.39, p = 4.4 × 10⁻⁵,
   reaching zero in 2079.** `alice-f7`, `sha256:b637a7ca04ee`.

That is six true statements, every one reproducible, and together they say *fog is being abolished*.

## Where it breaks

Same data, same container, same repository.

**The thunderstorm indicator falls further than the fog indicator.** On exactly the same
station-days, `gew` goes 8.66% → 5.09%, **−41.2%**, against fog's −30.6%. `alice-f4`,
`sha256:0c66ade55879`. Whatever is removing fog days from this file is removing thunderstorm days
faster, and Austrian thunderstorms have not been abolished.

**Fog days per thunderstorm day are flat.** On the unbroken-record stations the ratio is 0.819 in
1990-1994 and **0.843** in 2020-2024. `alice-f5`, `sha256:89b13602d4f9`. A fog-specific decline
should move this. It does not.

**The fog season did not change.** Per-month OLS on the unbroken-record panel — `alice-f9`,
`sha256:c54101776bbb`:

| month | fog days 1990-2025 | slope pp/yr | p | 1990s → 2016-25 |
|---|---|---|---|---|
| **Nov** | 329 | −0.010 | 0.944 | −5.5% |
| **Dec** | 288 | +0.045 | 0.713 | −8.6% |
| **Jan** | 256 | −0.115 | 0.458 | −23.5% |
| Aug | 14 | −0.036 | 0.030 | −100% |
| May | 14 | −0.019 | 0.233 | −80.2% |

The three months that hold 63% of all fog in the file show no significant trend at all. The
spectacular percentages are in months with a dozen fog days across 36 years.

**And the headline is a choice of window.** All 144 contiguous month-windows, each giving its own
1990-1994 → 2020-2024 change — `alice-f10`, `sha256:730968ba95b1`:

- NovDec: **−5.1%** · NovDecJan: **−4.4%** · DecJan: **−10.1%** · OctNovDecJan: **−18.5%** ·
  NovDecJanFeb: **−19.3%**
- windows built from spring and summer months: down to **−77%**

"Roughly a third" is what you get by mixing the fog season with eleven months that have almost no
fog to lose. It is not a property of Austrian fog; it is a property of the average.

**The extrapolation has no content.** The 2079 in point 6 above comes with a 95% interval on the
zero year, printed in the same CSV by the same run: **842 to 5208**. The point estimate is
rhetoric. The interval is the answer to it.

## What I would actually defend

Fog has declined at these ten Austrian stations, most clearly outside the deep winter, by an amount
this file cannot separate from a parallel decline in thunderstorm reporting. "Roughly a third" is
defensible only for the annual average, and the annual average is the wrong statistic. "On track to
disappear" is not supported by anything in this repository, and `alice-f10` is the run that says so.
