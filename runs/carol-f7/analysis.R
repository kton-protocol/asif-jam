# The fog season only. Fog in Austria is an October-to-March phenomenon: on the balanced panel
# Nov is 15.3% of days and Jul is 0.46%. Averaging the summer in dilutes the signal with months
# that have almost no fog to lose. This is the season-restricted series, balanced panel,
# labelled by the winter it belongs to (Oct 1990 - Mar 1991 is winter "1990").
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year  <- as.integer(substr(d$time, 1, 4))
d$month <- as.integer(substr(d$time, 6, 7))
d <- d[d$year >= 1990 & d$year <= 2024, ]

daysper <- tapply(rep(1, nrow(d)), list(d$year, d$station), sum)
repper  <- tapply(as.integer(!is.na(d$nebel)), list(d$year, d$station), sum)
complete <- colnames(repper)[apply(repper == daysper, 2, function(x) all(!is.na(x) & x))]
b <- d[as.character(d$station) %in% complete, ]

b <- b[b$month %in% c(10, 11, 12, 1, 2, 3), ]
b$winter <- ifelse(b$month >= 10, b$year, b$year - 1)
b <- b[b$winter >= 1990 & b$winter <= 2023, ]     # complete winters only
b$period <- paste0(b$winter - (b$winter %% 5), "-", b$winter - (b$winter %% 5) + 4)

per <- sort(unique(b$period))
agg <- data.frame(period = per,
  station_days = sapply(per, function(p) sum(b$period == p)),
  fog_days     = sapply(per, function(p) sum(b$period == p & b$nebel > 0)),
  stringsAsFactors = FALSE)
agg$fog_day_pct <- round(100 * agg$fog_days / agg$station_days, 2)

wtr <- sort(unique(b$winter))
ann <- data.frame(winter = wtr,
  station_days = sapply(wtr, function(w) sum(b$winter == w)),
  fog_days     = sapply(wtr, function(w) sum(b$winter == w & b$nebel > 0)),
  stringsAsFactors = FALSE)
ann$fog_day_pct <- 100 * ann$fog_days / ann$station_days
fit <- lm(fog_day_pct ~ winter, data = ann)
co <- summary(fit)$coefficients

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/fog-season-by-period.csv", row.names = FALSE)
write.csv(transform(ann, fog_day_pct = round(fog_day_pct, 3)),
          "out/fog-season-by-winter.csv", row.names = FALSE)

png("out/fog-season.png", width = 900, height = 560)
bp <- barplot(agg$fog_day_pct, names.arg = agg$period, las = 2, col = "grey30",
        ylab = "fog days (% of Oct-Mar station-days)", ylim = c(0, 14),
        main = "Fog days in the fog season (Oct-Mar), balanced panel")
text(bp, agg$fog_day_pct + 0.4, sprintf("%.2f", agg$fog_day_pct), cex = 0.9)
dev.off()

cat(sprintf("fog season %s: %.2f%% (1990-1994) -> %.2f%% (2020-2023): %+.1f%%\n",
            paste(complete, collapse = "+"),
            agg$fog_day_pct[1], agg$fog_day_pct[nrow(agg)],
            100 * agg$fog_day_pct[nrow(agg)] / agg$fog_day_pct[1] - 100))
cat(sprintf("winter trend: %.4f pp/winter (p = %.4g), zero in %.0f\n",
            co["winter", 1], co["winter", 4], -co["(Intercept)", 1] / co["winter", 1]))
print(agg)
