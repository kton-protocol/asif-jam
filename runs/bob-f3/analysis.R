# bob-f3 — THE HEADLINE. Fog rate on a complete-station-year panel.
#
# bob-f2 showed the naive denominator collapses across the window, so the naive rate is not a
# rate of a fixed thing. Fix it, by a rule stated before looking at the answer:
#
#   1. A (station, year) cell counts only if that station reported `nebel` on >= 350 days
#      of that year. Partial years are dropped entirely, not prorated.
#   2. A station is in the panel only if it has at least one such complete year in EVERY
#      five-year block 1990-1994 ... 2020-2024.
#   3. 2025 is excluded: the file ends mid-year and a partial block is not a block.
#
# The cell count and station-day count per period are written into the output so the
# denominator is auditable without re-running anything.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year <= 2024, ]

rep <- d[!is.na(d$nebel), ]
cell <- aggregate(list(days = rep$nebel), by = list(station = rep$station, year = rep$year),
                  FUN = length)
complete <- cell[cell$days >= 350, ]

blocks <- seq(1990, 2020, by = 5)
blk <- function(y) blocks[findInterval(y, blocks)]
complete$block <- blk(complete$year)

panel <- names(which(tapply(complete$block, complete$station,
                            function(b) length(unique(b)) == length(blocks))))
panel <- sort(as.integer(panel))
cat("panel stations:", paste(panel, collapse = ", "), "\n")

keep <- merge(rep, complete[complete$station %in% panel, c("station", "year")],
              by = c("station", "year"))
keep$block  <- blk(keep$year)
keep$period <- paste0(keep$block, "-", keep$block + 4)

agg <- aggregate(cbind(fog_days = keep$nebel > 0, station_days = rep(1, nrow(keep))),
                 by = list(period = keep$period), FUN = sum)
cells <- aggregate(list(cells = paste(keep$station, keep$year)),
                   by = list(period = keep$period), FUN = function(x) length(unique(x)))
agg <- merge(agg, cells, by = "period")
agg$fog_day_pct <- round(100 * agg$fog_days / agg$station_days, 2)
agg <- agg[order(agg$period), ]

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/fog-balanced-by-period.csv", row.names = FALSE)

png("out/fog-balanced-by-period.png", width = 900, height = 520)
par(mar = c(6, 5, 4, 2))
bp <- barplot(agg$fog_day_pct, names.arg = agg$period, las = 2, col = "#1f4e79",
              ylim = c(0, max(agg$fog_day_pct) * 1.25),
              ylab = "fog days (% of station-days, complete years only)",
              main = "Fog on a fixed panel of stations, Austria 1990-2024")
text(bp, agg$fog_day_pct + max(agg$fog_day_pct) * 0.06,
     labels = sprintf("%.2f%%\nn=%d", agg$fog_day_pct, agg$station_days), cex = 0.75)
dev.off()

first <- agg$fog_day_pct[1]; last <- agg$fog_day_pct[nrow(agg)]
cat(sprintf("fog rate %.2f%% -> %.2f%%  (%+.1f%%)\n", first, last, 100 * (last / first - 1)))
cat(sprintf("denominator %d -> %d station-days (%+.1f%%)\n",
            agg$station_days[1], agg$station_days[nrow(agg)],
            100 * (agg$station_days[nrow(agg)] / agg$station_days[1] - 1)))
print(agg)
