# alice-f4 -- the check the Defensio will run, run by me first.
#
# `gew` (thunderstorm day) plotted beside `nebel` on EXACTLY the same station-days: every row where
# both are reported. Same denominator, same rows, same axes. If the two fall together, the decline
# is about the reporting, not about the fog.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year   <- as.integer(substr(d$time, 1, 4))
d$month  <- as.integer(substr(d$time, 6, 7))
d$period <- paste0(d$year - (d$year %% 5), "-", d$year - (d$year %% 5) + 4)
dir.create("out", showWarnings = FALSE)

both <- d[!is.na(d$nebel) & !is.na(d$gew), ]
cat("station-days with both reported:", nrow(both), "of", nrow(d), "\n")

agg <- aggregate(cbind(nebel, gew) ~ period, data = both,
                 FUN = function(x) round(100 * mean(x > 0), 2))
agg$station_days <- aggregate(cbind(n = nebel) ~ period, data = both, FUN = length)$n
names(agg)[2:3] <- c("fog_day_pct", "storm_day_pct")
write.csv(agg, "out/fog-vs-storm-by-period.csv", row.names = FALSE)

png("out/fog-vs-storm-by-period.png", width = 900, height = 520)
m <- t(as.matrix(agg[, c("fog_day_pct", "storm_day_pct")]))
barplot(m, beside = TRUE, names.arg = agg$period, las = 2, ylim = c(0, 11),
        col = c("grey30", "grey70"),
        ylab = "% of the SAME station-days",
        main = "Fog days and thunderstorm days, identical station-days")
legend("topright", c("nebel (fog)", "gew (thunderstorm)"), fill = c("grey30", "grey70"), bty = "n")
dev.off()
print(agg)
a <- agg[agg$period == "1990-1994", ]; z <- agg[agg$period == "2020-2024", ]
cat(sprintf("1990-1994 -> 2020-2024:  fog %+.1f%%   storm %+.1f%%\n",
            100 * z$fog_day_pct / a$fog_day_pct - 100,
            100 * z$storm_day_pct / a$storm_day_pct - 100))
cat("wrote out/fog-vs-storm-by-period.csv and .png\n")
