# alice-f7 -- "on track to disappear", made into a number instead of an adjective.
#
# Ordinary least squares on the annual fog-day rate, all reporting station-days, extended to the
# year the fitted line reaches zero. The extrapolation is arithmetic, not physics: it is printed
# together with the confidence band and with the last year's observed value, so a reader can see
# exactly how much of "on track to disappear" is the data and how much is the straight line.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year   <- as.integer(substr(d$time, 1, 4))
d$month  <- as.integer(substr(d$time, 6, 7))
d$period <- paste0(d$year - (d$year %% 5), "-", d$year - (d$year %% 5) + 4)
dir.create("out", showWarnings = FALSE)

f  <- d[!is.na(d$nebel), ]
yr <- aggregate(cbind(fog_days = nebel) ~ year, data = f, FUN = function(x) sum(x > 0))
yr$station_days <- aggregate(cbind(n = nebel) ~ year, data = f, FUN = length)$n
yr$fog_day_pct  <- round(100 * yr$fog_days / yr$station_days, 3)

fit  <- lm(fog_day_pct ~ year, data = yr)
co   <- coef(fit)
zero <- as.numeric(-co[1] / co[2])
ci   <- confint(fit)
zlo  <- as.numeric(-ci[1, 1] / ci[2, 1]); zhi <- as.numeric(-ci[1, 2] / ci[2, 2])
res  <- data.frame(slope_pp_per_year = round(co[2], 4),
                   intercept = round(co[1], 2),
                   r_squared = round(summary(fit)$r.squared, 3),
                   p_value = signif(summary(fit)$coefficients[2, 4], 3),
                   zero_year = round(zero, 1),
                   zero_year_ci_lo = round(min(zlo, zhi), 1),
                   zero_year_ci_hi = round(max(zlo, zhi), 1),
                   last_observed_year = max(yr$year),
                   last_observed_pct = yr$fog_day_pct[which.max(yr$year)])
write.csv(yr,  "out/fog-annual-rate.csv", row.names = FALSE)
write.csv(res, "out/fog-extrapolation.csv", row.names = FALSE)

png("out/fog-extrapolation.png", width = 950, height = 540)
plot(yr$year, yr$fog_day_pct, pch = 19, xlim = c(1990, ceiling(zero / 10) * 10),
     ylim = c(0, 12), xlab = "year", ylab = "fog days (% of reporting station-days)",
     main = "Austrian fog days, observed 1990-2025 and the fitted line extended to zero")
nd <- data.frame(year = 1990:ceiling(zero))
pr <- predict(fit, nd, interval = "confidence")
lines(nd$year, pr[, "fit"], col = "red", lwd = 2)
lines(nd$year, pr[, "lwr"], col = "red", lty = 3); lines(nd$year, pr[, "upr"], col = "red", lty = 3)
abline(h = 0, col = "grey50"); abline(v = zero, col = "blue", lty = 2)
text(zero, 11, sprintf("fitted zero: %.0f", zero), pos = 2, col = "blue")
dev.off()
print(res)
cat("wrote out/fog-annual-rate.csv, out/fog-extrapolation.csv and out/fog-extrapolation.png\n")
