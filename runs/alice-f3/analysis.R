# alice-f3 -- the strictest denominator available in this file.
#
# Only two stations (80 and 105) reported `nebel` on >= 350 days in EVERY one of the 36 years.
# The panel is derived here rather than hard-coded, so the selection rule is in the record.
# On these two stations nothing about the denominator changes, at all, across the whole window.
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
panel <- good$station[good$fullyears == length(unique(d$year))]
cat("complete-record stations:", paste(sort(panel), collapse = ", "), "\n")

p <- d[d$station %in% panel, ]
yr <- aggregate(cbind(fog_days = nebel) ~ year, data = p, FUN = function(x) sum(x > 0))
yr$station_days <- aggregate(cbind(n = nebel) ~ year, data = p, FUN = length)$n
yr$fog_day_pct  <- round(100 * yr$fog_days / yr$station_days, 2)
write.csv(yr, "out/fog-complete-panel-by-year.csv", row.names = FALSE)

fit <- lm(fog_day_pct ~ year, data = yr)
png("out/fog-complete-panel-by-year.png", width = 900, height = 520)
plot(yr$year, yr$fog_day_pct, type = "b", pch = 19, lwd = 2, ylim = c(0, 12),
     xlab = "year", ylab = "fog days (% of station-days)",
     main = paste0("Fog days at the ", length(panel),
                   " Austrian stations with an unbroken record, 1990-2025"))
abline(fit, col = "red", lwd = 2, lty = 2)
dev.off()
print(yr)
print(summary(fit)$coefficients)
cat("wrote out/fog-complete-panel-by-year.csv and .png\n")
