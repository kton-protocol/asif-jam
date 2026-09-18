# bob-f4 — THE ATTACK I RUN ON MYSELF.
#
# TASK.md names the check that would sink me: "plot `gew` beside `nebel` on the same
# station-days". So that is exactly what this does, on bob-f3's panel, on the identical
# rows -- not merely the same stations and years, but the same station-days, requiring
# BOTH indicators to be present in the same row.
#
# If `gew` falls by as much as `nebel`, then whatever changed was not the weather.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year <= 2024, ]

# identical panel rule to bob-f3
rep  <- d[!is.na(d$nebel), ]
cell <- aggregate(list(days = rep$nebel), by = list(station = rep$station, year = rep$year),
                  FUN = length)
complete <- cell[cell$days >= 350, ]
blocks <- seq(1990, 2020, by = 5)
blk <- function(y) blocks[findInterval(y, blocks)]
complete$block <- blk(complete$year)
panel <- names(which(tapply(complete$block, complete$station,
                            function(b) length(unique(b)) == length(blocks))))
panel <- sort(as.integer(panel))

keep <- merge(rep, complete[complete$station %in% panel, c("station", "year")],
              by = c("station", "year"))
# the strict version: same ROW must carry both indicators
keep <- keep[!is.na(keep$gew), ]
keep$block  <- blk(keep$year)
keep$period <- paste0(keep$block, "-", keep$block + 4)

agg <- aggregate(cbind(fog = keep$nebel > 0, storm = keep$gew > 0,
                       station_days = rep(1, nrow(keep))),
                 by = list(period = keep$period), FUN = sum)
agg$fog_pct   <- round(100 * agg$fog   / agg$station_days, 2)
agg$storm_pct <- round(100 * agg$storm / agg$station_days, 2)
agg <- agg[order(agg$period), ]

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/nebel-vs-gew-same-days.csv", row.names = FALSE)

png("out/nebel-vs-gew-same-days.png", width = 900, height = 520)
par(mar = c(6, 5, 4, 2))
m <- rbind(agg$fog_pct, agg$storm_pct)
bp <- barplot(m, beside = TRUE, names.arg = agg$period, las = 2,
              col = c("#1f4e79", "#c0504d"), ylim = c(0, max(m) * 1.2),
              ylab = "% of the SAME station-days",
              main = "nebel and gew, identical rows, fixed panel")
legend("topright", bty = "n", fill = c("#1f4e79", "#c0504d"),
       legend = c("nebel (fog day)", "gew (thunderstorm day)"))
dev.off()

n <- nrow(agg)
cat(sprintf("fog   %.2f%% -> %.2f%%  (%+.1f%%)\n", agg$fog_pct[1], agg$fog_pct[n],
            100 * (agg$fog_pct[n] / agg$fog_pct[1] - 1)))
cat(sprintf("storm %.2f%% -> %.2f%%  (%+.1f%%)\n", agg$storm_pct[1], agg$storm_pct[n],
            100 * (agg$storm_pct[n] / agg$storm_pct[1] - 1)))
cat(sprintf("shared denominator %d -> %d station-days (%+.1f%%)\n",
            agg$station_days[1], agg$station_days[n],
            100 * (agg$station_days[n] / agg$station_days[1] - 1)))
print(agg)
