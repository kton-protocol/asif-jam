# Every station, every reporting day, with station fixed effects.
#
# The balanced panel is airtight but it is two stations. This uses all ten and all 109,496
# reporting station-days, and absorbs the composition problem into the model instead of the sample:
# a logistic regression of the fog-day indicator on year with a fixed effect per station. The year
# coefficient is then a within-station trend — it cannot be produced by which stations are present.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year >= 1990 & d$year <= 2024 & !is.na(d$nebel), ]
d$fog <- as.integer(d$nebel > 0)
d$st  <- factor(d$station)
d$t   <- d$year - 1990

m <- glm(fog ~ t + st, data = d, family = binomial())
co <- summary(m)$coefficients["t", ]
or <- exp(co[1])

# per-station trend, each station on its own reporting days
sts <- levels(d$st)
tab <- do.call(rbind, lapply(sts, function(s) {
  x <- d[d$st == s, ]
  yrs <- sort(unique(x$year))
  p <- sapply(yrs, function(y) 100 * mean(x$fog[x$year == y]))
  f <- lm(p ~ yrs)
  data.frame(station = s, years = length(yrs), first_year = min(yrs), last_year = max(yrs),
             reporting_days = nrow(x), mean_pct = round(100 * mean(x$fog), 2),
             slope_pp_per_yr = round(coef(f)[2], 4),
             p_value = round(summary(f)$coefficients[2, 4], 4),
             stringsAsFactors = FALSE)
}))

dir.create("out", showWarnings = FALSE)
write.csv(tab, "out/per-station-trends.csv", row.names = FALSE)
writeLines(c(
  sprintf("logistic fog ~ year + station, n = %d reporting station-days, %d stations",
          nrow(d), length(sts)),
  sprintf("year coefficient: %.5f (se %.5f, z = %.2f, p = %.3g)", co[1], co[2], co[3], co[4]),
  sprintf("odds ratio per year: %.5f  -> %.2f%% per year, %.1f%% over 34 years",
          or, 100 * (or - 1), 100 * (or^34 - 1)),
  sprintf("stations with a negative fitted trend: %d of %d",
          sum(tab$slope_pp_per_yr < 0), nrow(tab)),
  sprintf("stations with a negative trend at p < 0.05: %d",
          sum(tab$slope_pp_per_yr < 0 & tab$p_value < 0.05))),
  "out/fixed-effects.txt")

png("out/per-station-trends.png", width = 900, height = 560)
o <- order(tab$slope_pp_per_yr)
bp <- barplot(tab$slope_pp_per_yr[o], names.arg = tab$station[o], las = 2,
        col = ifelse(tab$p_value[o] < 0.05, "grey20", "grey70"),
        ylab = "trend in fog-day % per year", xlab = "station",
        main = "Within-station fog trend, 1990-2024 (dark = p < 0.05)")
abline(h = 0)
dev.off()

cat(readLines("out/fixed-effects.txt"), sep = "\n"); cat("\n"); print(tab)
