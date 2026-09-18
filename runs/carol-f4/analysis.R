# "Show us the count, not the rate." Here is the count, both ways.
#
# Panel A: fog days counted over every station in the file. This number falls hard, but part of
#          that fall is stations leaving the network, so on its own it proves nothing.
# Panel B: fog days counted over the balanced panel only (stations 80 and 105, which reported
#          every day of every year). Here the count and the rate are the same statement, because
#          the number of station-days per period is constant.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year >= 1990 & d$year <= 2024, ]
d$period <- paste0(d$year - (d$year %% 5), "-", d$year - (d$year %% 5) + 4)

daysper <- tapply(rep(1, nrow(d)), list(d$year, d$station), sum)
repper  <- tapply(as.integer(!is.na(d$nebel)), list(d$year, d$station), sum)
complete <- colnames(repper)[apply(repper == daysper, 2, function(x) all(!is.na(x) & x))]
b <- d[as.character(d$station) %in% complete, ]

per <- sort(unique(d$period))
cnt <- function(x, p) sum(x$period == p & !is.na(x$nebel) & x$nebel > 0)
den <- function(x, p) sum(x$period == p & !is.na(x$nebel))
agg <- data.frame(period = per,
  all_fog_days = sapply(per, function(p) cnt(d, p)),
  all_station_days = sapply(per, function(p) den(d, p)),
  bal_fog_days = sapply(per, function(p) cnt(b, p)),
  bal_station_days = sapply(per, function(p) den(b, p)),
  stringsAsFactors = FALSE)

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/fog-counts.csv", row.names = FALSE)

png("out/fog-counts.png", width = 900, height = 620)
par(mfrow = c(2, 1), mar = c(5, 5, 3, 2))
barplot(agg$all_fog_days, names.arg = agg$period, las = 2, col = "grey60",
        ylab = "fog days counted", main = "A. Fog days, all stations (denominator NOT constant)")
barplot(agg$bal_fog_days, names.arg = agg$period, las = 2, col = "grey25",
        ylab = "fog days counted", main = "B. Fog days, balanced panel (denominator constant)")
dev.off()

f <- function(v) 100 * v[length(v)] / v[1] - 100
cat(sprintf("all stations : %d -> %d fog days (%+.1f%%), over %d -> %d station-days (%+.1f%%)\n",
            agg$all_fog_days[1], agg$all_fog_days[nrow(agg)], f(agg$all_fog_days),
            agg$all_station_days[1], agg$all_station_days[nrow(agg)], f(agg$all_station_days)))
cat(sprintf("balanced     : %d -> %d fog days (%+.1f%%), over %d -> %d station-days (%+.1f%%)\n",
            agg$bal_fog_days[1], agg$bal_fog_days[nrow(agg)], f(agg$bal_fog_days),
            agg$bal_station_days[1], agg$bal_station_days[nrow(agg)], f(agg$bal_station_days)))
print(agg)
