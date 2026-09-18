# The denominator audit. Before I argue anything I want to know what I am dividing by.
# Counts the station-days that REPORTED nebel, and the station-days that reported gew, per period,
# and prints both rates beside both denominators.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year   <- as.integer(substr(d$time, 1, 4))
d$period <- paste0(d$year - (d$year %% 5), "-", d$year - (d$year %% 5) + 4)

per <- sort(unique(d$period))
res <- data.frame(period = per,
  rows          = sapply(per, function(p) sum(d$period == p)),
  nebel_report  = sapply(per, function(p) sum(d$period == p & !is.na(d$nebel))),
  nebel_days    = sapply(per, function(p) sum(d$period == p & !is.na(d$nebel) & d$nebel > 0)),
  gew_report    = sapply(per, function(p) sum(d$period == p & !is.na(d$gew))),
  gew_days      = sapply(per, function(p) sum(d$period == p & !is.na(d$gew) & d$gew > 0)),
  stringsAsFactors = FALSE)
res$nebel_pct <- round(100 * res$nebel_days / res$nebel_report, 2)
res$gew_pct   <- round(100 * res$gew_days   / res$gew_report,   2)
res$nebel_report_idx <- round(100 * res$nebel_report / res$nebel_report[1], 1)
res$gew_report_idx   <- round(100 * res$gew_report   / res$gew_report[1],   1)

dir.create("out", showWarnings = FALSE)
write.csv(res, "out/denominator-audit.csv", row.names = FALSE)

png("out/denominator-audit.png", width = 900, height = 620)
par(mfrow = c(2, 1), mar = c(5, 5, 3, 2))
barplot(rbind(res$nebel_report, res$gew_report), beside = TRUE,
        names.arg = res$period, las = 2, col = c("grey30", "grey70"),
        ylab = "station-days reporting",
        main = "Denominator: station-days that reported at all")
legend("topright", c("nebel", "gew"), fill = c("grey30", "grey70"), bty = "n")
plot(seq_along(per), res$nebel_pct, type = "b", lwd = 2, pch = 19, ylim = c(0, 11),
     xaxt = "n", xlab = "", ylab = "% of reporting station-days",
     main = "Rate, nebel and gew")
lines(seq_along(per), res$gew_pct, type = "b", lwd = 2, pch = 17, lty = 2)
axis(1, at = seq_along(per), labels = res$period, las = 2)
legend("bottomleft", c("nebel", "gew"), lwd = 2, pch = c(19, 17), lty = c(1, 2), bty = "n")
dev.off()

cat("denominator change, first to 2020-2024 period:\n")
i <- which(res$period == "2020-2024")
cat(sprintf("  nebel reporting station-days: %d -> %d  (%.1f%%)\n",
            res$nebel_report[1], res$nebel_report[i],
            100 * res$nebel_report[i] / res$nebel_report[1] - 100))
cat(sprintf("  gew   reporting station-days: %d -> %d  (%.1f%%)\n",
            res$gew_report[1], res$gew_report[i],
            100 * res$gew_report[i] / res$gew_report[1] - 100))
print(res)
