# bob-f7 — "SHOW US THE COUNT, NOT THE RATE."
#
# TASK.md writes the good Defensio for me, so I write the figure it demands. Three series
# on one axis, all on the fixed panel of complete station-years:
#
#   fog days           the numerator
#   station-days       the denominator
#   fog days per       what you get if you refuse to divide by a moving number and instead
#   complete station-  divide by a COUNT OF STATIONS-YEARS, which is an integer you can
#   year               check by eye
#
# Nothing here is a percentage of anything that moved.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year <= 2024, ]

rep  <- d[!is.na(d$nebel), ]
cnt  <- aggregate(list(days = rep$nebel), by = list(station = rep$station, year = rep$year),
                  FUN = length)
fogd <- aggregate(list(fog = rep$nebel > 0), by = list(station = rep$station, year = rep$year),
                  FUN = sum)
cell <- merge(cnt, fogd, by = c("station", "year"))
cell <- cell[cell$days >= 350, ]
blocks <- seq(1990, 2020, by = 5)
cell$block <- blocks[findInterval(cell$year, blocks)]
panel <- names(which(tapply(cell$block, cell$station,
                            function(b) length(unique(b)) == length(blocks))))
cell <- cell[cell$station %in% panel, ]

yr <- aggregate(cbind(fog_days = cell$fog, station_days = cell$days,
                      complete_station_years = rep(1, nrow(cell))),
                by = list(year = cell$year), FUN = sum)
yr$fog_days_per_station_year <- round(yr$fog_days / yr$complete_station_years, 2)
yr <- yr[order(yr$year), ]

dir.create("out", showWarnings = FALSE)
write.csv(yr, "out/fog-counts-by-year.csv", row.names = FALSE)

png("out/fog-counts-by-year.png", width = 1000, height = 620)
par(mfrow = c(3, 1), mar = c(3, 6, 2.5, 2), oma = c(3, 0, 2, 0))
plot(yr$year, yr$fog_days, type = "h", lwd = 6, col = "#1f4e79",
     ylim = c(0, max(yr$fog_days) * 1.1), xlab = "", ylab = "fog days\n(numerator)")
title("Counts, not rates: fixed panel of complete station-years", outer = TRUE)
plot(yr$year, yr$complete_station_years, type = "h", lwd = 6, col = "grey45",
     ylim = c(0, max(yr$complete_station_years) + 1), xlab = "",
     ylab = "complete\nstation-years")
plot(yr$year, yr$fog_days_per_station_year, type = "b", pch = 19, lwd = 2, col = "#c0504d",
     ylim = c(0, max(yr$fog_days_per_station_year) * 1.1), xlab = "year",
     ylab = "fog days per\nstation-year")
abline(lm(fog_days_per_station_year ~ year, data = yr), lty = 2, col = "#c0504d")
mtext("year", side = 1, outer = TRUE, line = 1)
dev.off()

m <- lm(fog_days_per_station_year ~ year, data = yr)
cat(sprintf("fog days per station-year: %.2f (1990) -> %.2f (2024)\n",
            yr$fog_days_per_station_year[1], yr$fog_days_per_station_year[nrow(yr)]))
cat(sprintf("OLS slope %.3f days/year (p = %.4g)\n",
            coef(m)["year"], summary(m)$coefficients["year", 4]))
print(yr)
