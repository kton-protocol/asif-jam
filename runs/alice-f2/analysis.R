# alice-f2 -- the same rate, on a STATION PANEL that does not change.
#
# Objection this answers: "your denominator moved because stations dropped out". Here the station
# set is fixed in advance: every station that reported `nebel` on at least 350 days in at least 34
# of the 36 years. Nothing about fog enters the selection rule -- only reporting completeness.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year   <- as.integer(substr(d$time, 1, 4))
d$month  <- as.integer(substr(d$time, 6, 7))
d$period <- paste0(d$year - (d$year %% 5), "-", d$year - (d$year %% 5) + 4)
dir.create("out", showWarnings = FALSE)

rep  <- aggregate(list(n = !is.na(d$nebel)), by = list(station = d$station, year = d$year), FUN = sum)
good <- aggregate(list(fullyears = rep$n >= 350), by = list(station = rep$station), FUN = sum)
panel <- good$station[good$fullyears >= 34]
cat("panel stations:", paste(sort(panel), collapse = ", "), "\n")

p <- d[d$station %in% panel & !is.na(d$nebel), ]
agg <- aggregate(cbind(fog_day_pct = nebel) ~ period, data = p,
                 FUN = function(x) round(100 * mean(x > 0), 2))
n   <- aggregate(cbind(station_days = nebel) ~ period, data = p, FUN = length)
agg <- merge(agg, n, by = "period")
write.csv(agg, "out/fog-panel34-by-period.csv", row.names = FALSE)

png("out/fog-panel34-by-period.png", width = 900, height = 520)
bp <- barplot(agg$fog_day_pct, names.arg = agg$period, las = 2, ylim = c(0, 11),
        ylab = "fog days (% of station-days)",
        main = paste0("Fog days, fixed panel of ", length(panel), " stations (1990-2025)"))
text(bp, agg$fog_day_pct + 0.4, sprintf("%.2f", agg$fog_day_pct), cex = 0.9)
dev.off()
print(agg)
cat("wrote out/fog-panel34-by-period.csv and .png\n")
