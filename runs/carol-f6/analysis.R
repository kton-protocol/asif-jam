# The annual series on the balanced panel, a least-squares trend through it, and the year the
# fitted line reaches zero. Every number here is from the file and the fit is an ordinary lm().
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year >= 1990 & d$year <= 2024, ]

daysper <- tapply(rep(1, nrow(d)), list(d$year, d$station), sum)
repper  <- tapply(as.integer(!is.na(d$nebel)), list(d$year, d$station), sum)
complete <- colnames(repper)[apply(repper == daysper, 2, function(x) all(!is.na(x) & x))]
b <- d[as.character(d$station) %in% complete, ]

yrs <- sort(unique(b$year))
ann <- data.frame(year = yrs,
  station_days = sapply(yrs, function(y) sum(b$year == y)),
  fog_days     = sapply(yrs, function(y) sum(b$year == y & b$nebel > 0)),
  stringsAsFactors = FALSE)
ann$fog_day_pct <- 100 * ann$fog_days / ann$station_days

fit <- lm(fog_day_pct ~ year, data = ann)
co  <- summary(fit)$coefficients
slope <- co["year", 1]; se <- co["year", 2]; p <- co["year", 4]
zero  <- -co["(Intercept)", 1] / slope

ann$fitted <- round(fitted(fit), 3)
ann$fog_day_pct <- round(ann$fog_day_pct, 3)

dir.create("out", showWarnings = FALSE)
write.csv(ann, "out/fog-annual-balanced.csv", row.names = FALSE)
writeLines(c(
  sprintf("stations in balanced panel: %s", paste(complete, collapse = ", ")),
  sprintf("years: %d-%d, station-days per year: %d-%d",
          min(yrs), max(yrs), min(ann$station_days), max(ann$station_days)),
  sprintf("slope: %.4f percentage points per year (se %.4f, p = %.4g)", slope, se, p),
  sprintf("R^2: %.3f", summary(fit)$r.squared),
  sprintf("fitted value 1990: %.2f%%   fitted value 2024: %.2f%%",
          predict(fit, data.frame(year = 1990)), predict(fit, data.frame(year = 2024))),
  sprintf("fitted decline 1990-2024: %.1f%%",
          100 * predict(fit, data.frame(year = 2024)) / predict(fit, data.frame(year = 1990)) - 100),
  sprintf("the fitted line reaches zero in %.0f", zero)),
  "out/fog-trend.txt")

png("out/fog-trend.png", width = 900, height = 560)
plot(ann$year, ann$fog_day_pct, type = "p", pch = 19, col = "grey30",
     xlim = c(1990, ceiling(zero)), ylim = c(0, max(ann$fog_day_pct) * 1.05),
     xlab = "year", ylab = "fog days (% of station-days)",
     main = "Fog days per year, balanced panel, with least-squares trend")
lines(ann$year, fitted(fit), lwd = 2)
xs <- seq(2024, zero, length.out = 100)
lines(xs, predict(fit, data.frame(year = xs)), lwd = 2, lty = 3)
abline(h = 0, col = "grey70")
points(zero, 0, pch = 4, cex = 1.6, lwd = 2)
text(zero, 0.35, sprintf("%.0f", zero), cex = 1.1)
dev.off()

cat(readLines("out/fog-trend.txt"), sep = "\n")
