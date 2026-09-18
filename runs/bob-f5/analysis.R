# bob-f5 — SEASONALITY, which is my answer to bob-f4.
#
# bob-f4 will show gew falling too, and the obvious reading of that is "both indicators
# fell, so observing practice changed, not the weather". This run tests whether the two
# indicators even live in the same part of the year. If fog is an October-January
# phenomenon and thunderstorms are a May-August one, a single change in observing
# practice would have to have been applied in both seasons.
#
# Also splits fog by season across the window, to see WHERE the decline sits.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year  <- as.integer(substr(d$time, 1, 4))
d$month <- as.integer(substr(d$time, 6, 7))
d <- d[d$year <= 2024, ]

rep  <- d[!is.na(d$nebel), ]
cell <- aggregate(list(days = rep$nebel), by = list(station = rep$station, year = rep$year),
                  FUN = length)
complete <- cell[cell$days >= 350, ]
blocks <- seq(1990, 2020, by = 5)
blk <- function(y) blocks[findInterval(y, blocks)]
complete$block <- blk(complete$year)
panel <- names(which(tapply(complete$block, complete$station,
                            function(b) length(unique(b)) == length(blocks))))
keep <- merge(rep, complete[complete$station %in% panel, c("station", "year")],
              by = c("station", "year"))
keep <- keep[!is.na(keep$gew), ]

mon <- aggregate(cbind(fog = keep$nebel > 0, storm = keep$gew > 0,
                       n = rep(1, nrow(keep))),
                 by = list(month = keep$month), FUN = sum)
mon$fog_pct   <- round(100 * mon$fog   / mon$n, 2)
mon$storm_pct <- round(100 * mon$storm / mon$n, 2)
mon <- mon[order(mon$month), ]

# fog season (Oct-Jan) vs the rest, early half vs late half
keep$fogseason <- ifelse(keep$month %in% c(10, 11, 12, 1), "Oct-Jan", "Feb-Sep")
keep$half      <- ifelse(keep$year <= 2007, "1990-2007", "2008-2024")
sea <- aggregate(cbind(fog = keep$nebel > 0, n = rep(1, nrow(keep))),
                 by = list(season = keep$fogseason, half = keep$half), FUN = sum)
sea$fog_pct <- round(100 * sea$fog / sea$n, 2)

dir.create("out", showWarnings = FALSE)
write.csv(mon, "out/fog-storm-by-month.csv", row.names = FALSE)
write.csv(sea, "out/fog-by-season-half.csv", row.names = FALSE)

png("out/fog-storm-seasonality.png", width = 900, height = 520)
par(mar = c(5, 5, 4, 2))
plot(mon$month, mon$fog_pct, type = "b", pch = 19, lwd = 3, col = "#1f4e79",
     ylim = c(0, max(c(mon$fog_pct, mon$storm_pct)) * 1.15), xaxt = "n",
     xlab = "month", ylab = "% of station-days on the fixed panel",
     main = "The two indicators do not share a season")
lines(mon$month, mon$storm_pct, type = "b", pch = 17, lwd = 3, col = "#c0504d")
axis(1, at = 1:12, labels = c("J","F","M","A","M","J","J","A","S","O","N","D"))
legend("top", bty = "n", lwd = 3, pch = c(19, 17), col = c("#1f4e79", "#c0504d"),
       legend = c("nebel (fog)", "gew (thunderstorm)"))
dev.off()

print(mon[, c("month", "fog_pct", "storm_pct", "n")])
print(sea)
