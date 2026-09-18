# gew beside nebel, on exactly the same station-days. The third thing the other side will do.
#
# Panel A: both rates on the balanced panel (stations that reported every day 1990-2024), so the
#          denominator is identical for the two series by construction.
# Panel B: the month-of-year profile of both, which is the reason A is not the control it looks
#          like: nebel is a November phenomenon and gew is a July one. They do not share a season,
#          so they do not share a weather regime either.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year  <- as.integer(substr(d$time, 1, 4))
d$month <- as.integer(substr(d$time, 6, 7))
d <- d[d$year >= 1990 & d$year <= 2024, ]
d$period <- paste0(d$year - (d$year %% 5), "-", d$year - (d$year %% 5) + 4)

daysper <- tapply(rep(1, nrow(d)), list(d$year, d$station), sum)
repper  <- tapply(as.integer(!is.na(d$nebel)), list(d$year, d$station), sum)
complete <- colnames(repper)[apply(repper == daysper, 2, function(x) all(!is.na(x) & x))]
b <- d[as.character(d$station) %in% complete, ]
b <- b[!is.na(b$nebel) & !is.na(b$gew), ]   # same station-days for both series

per <- sort(unique(b$period))
agg <- data.frame(period = per,
  station_days = sapply(per, function(p) sum(b$period == p)),
  nebel_days   = sapply(per, function(p) sum(b$period == p & b$nebel > 0)),
  gew_days     = sapply(per, function(p) sum(b$period == p & b$gew   > 0)),
  stringsAsFactors = FALSE)
agg$nebel_pct <- round(100 * agg$nebel_days / agg$station_days, 2)
agg$gew_pct   <- round(100 * agg$gew_days   / agg$station_days, 2)

mon <- data.frame(month = 1:12,
  nebel_pct = sapply(1:12, function(m) round(100 * mean(b$nebel[b$month == m] > 0), 2)),
  gew_pct   = sapply(1:12, function(m) round(100 * mean(b$gew[b$month == m]   > 0), 2)))

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/nebel-vs-gew-balanced.csv", row.names = FALSE)
write.csv(mon, "out/nebel-vs-gew-monthly.csv", row.names = FALSE)

png("out/nebel-vs-gew.png", width = 900, height = 620)
par(mfrow = c(2, 1), mar = c(5, 5, 3, 2))
plot(seq_along(per), agg$nebel_pct, type = "b", pch = 19, lwd = 2, ylim = c(0, 10), xaxt = "n",
     xlab = "", ylab = "% of station-days",
     main = "A. Same station-days, same denominator: nebel and gew")
lines(seq_along(per), agg$gew_pct, type = "b", pch = 17, lwd = 2, lty = 2)
axis(1, at = seq_along(per), labels = agg$period, las = 2)
legend("bottomleft", c("nebel (fog)", "gew (thunderstorm)"), lwd = 2, pch = c(19, 17),
       lty = c(1, 2), bty = "n")
barplot(rbind(mon$nebel_pct, mon$gew_pct), beside = TRUE, names.arg = month.abb,
        col = c("grey25", "grey70"), ylab = "% of station-days",
        main = "B. They are not the same season")
legend("topright", c("nebel", "gew"), fill = c("grey25", "grey70"), bty = "n")
dev.off()

f <- function(v) 100 * v[length(v)] / v[1] - 100
cat(sprintf("balanced panel, %s: nebel %.2f -> %.2f (%+.1f%%), gew %.2f -> %.2f (%+.1f%%)\n",
            paste(complete, collapse = "+"),
            agg$nebel_pct[1], agg$nebel_pct[nrow(agg)], f(agg$nebel_pct),
            agg$gew_pct[1],   agg$gew_pct[nrow(agg)],   f(agg$gew_pct)))
print(agg); print(mon)
