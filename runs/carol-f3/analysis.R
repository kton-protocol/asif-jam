# The balanced panel. The denominator objection, answered by removing the denominator.
#
# Keep only stations that reported nebel on EVERY calendar day of EVERY year 1990-2024 (365/366).
# For those stations the denominator is constant by construction: the same instruments, the same
# observers, the same number of station-days in every period. Nothing about network attrition,
# station closure or changed reporting practice can move this series.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year >= 1990 & d$year <= 2024, ]
d$rep <- !is.na(d$nebel)

# days in each year, and the stations that reported on all of them, every year
daysper <- tapply(rep(1, nrow(d)), list(d$year, d$station), sum)
repper  <- tapply(as.integer(d$rep), list(d$year, d$station), sum)
complete <- colnames(repper)[apply(repper == daysper, 2, function(x) all(!is.na(x) & x))]
cat("complete stations:", paste(complete, collapse = ", "), "\n")

b <- d[d$station %in% as.integer(complete) | as.character(d$station) %in% complete, ]
b$period <- paste0(b$year - (b$year %% 5), "-", b$year - (b$year %% 5) + 4)

per <- sort(unique(b$period))
agg <- data.frame(period = per,
  station_days = sapply(per, function(p) sum(b$period == p)),
  fog_days     = sapply(per, function(p) sum(b$period == p & b$nebel > 0)),
  stringsAsFactors = FALSE)
agg$fog_day_pct <- round(100 * agg$fog_days / agg$station_days, 2)

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/fog-balanced-panel.csv", row.names = FALSE)

drop <- 100 * agg$fog_day_pct[nrow(agg)] / agg$fog_day_pct[1] - 100
png("out/fog-balanced-panel.png", width = 900, height = 520)
bp <- barplot(agg$fog_day_pct, names.arg = agg$period, las = 2, col = "grey35",
        ylab = "fog days (% of station-days)", ylim = c(0, 8),
        main = sprintf("Fog days, balanced panel of %d stations reporting every day 1990-2024",
                       length(complete)))
text(bp, agg$fog_day_pct + 0.25, sprintf("%.2f", agg$fog_day_pct), cex = 0.9)
dev.off()

cat(sprintf("balanced panel: %d stations, %d station-days per period (constant)\n",
            length(complete), agg$station_days[1]))
cat(sprintf("fog-day rate %.2f%% (1990-1994) -> %.2f%% (2020-2024): %+.1f%%\n",
            agg$fog_day_pct[1], agg$fog_day_pct[nrow(agg)], drop))
print(agg)
