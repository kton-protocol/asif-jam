# bob-f2 — DENOMINATOR AUDIT.
#
# Before arguing anything about fog I want to know what the naive rate is a rate OF.
# Per year: how many station-days reported `nebel` at all, how many reported `gew`,
# and how many distinct stations were behind each.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))

years <- sort(unique(d$year))
tab <- data.frame(
  year            = years,
  rows            = sapply(years, function(y) sum(d$year == y)),
  nebel_reported  = sapply(years, function(y) sum(d$year == y & !is.na(d$nebel))),
  gew_reported    = sapply(years, function(y) sum(d$year == y & !is.na(d$gew))),
  nebel_stations  = sapply(years, function(y) length(unique(d$station[d$year == y & !is.na(d$nebel)]))),
  gew_stations    = sapply(years, function(y) length(unique(d$station[d$year == y & !is.na(d$gew)])))
)
tab$nebel_coverage_pct <- round(100 * tab$nebel_reported / tab$rows, 2)
tab$gew_coverage_pct   <- round(100 * tab$gew_reported   / tab$rows, 2)

dir.create("out", showWarnings = FALSE)
write.csv(tab, "out/denominator-by-year.csv", row.names = FALSE)

png("out/denominator-by-year.png", width = 900, height = 520)
par(mar = c(5, 5, 4, 2))
plot(tab$year, tab$nebel_reported, type = "l", lwd = 3, col = "#1f4e79",
     ylim = c(0, max(tab$rows)),
     xlab = "year", ylab = "station-days reporting the indicator",
     main = "What the fog rate is a rate OF")
lines(tab$year, tab$gew_reported, lwd = 3, col = "#c0504d")
lines(tab$year, tab$rows, lwd = 1, lty = 3, col = "grey40")
legend("bottomleft", bty = "n", lwd = c(3, 3, 1), lty = c(1, 1, 3),
       col = c("#1f4e79", "#c0504d", "grey40"),
       legend = c("nebel reported", "gew reported", "rows in file (10 stations x 365d)"))
dev.off()

cat("nebel denominator", tab$nebel_reported[1], "->", tab$nebel_reported[nrow(tab)],
    sprintf("(%+.1f%%)\n", 100 * (tab$nebel_reported[nrow(tab)] / tab$nebel_reported[1] - 1)))
cat("gew   denominator", tab$gew_reported[1], "->", tab$gew_reported[nrow(tab)],
    sprintf("(%+.1f%%)\n", 100 * (tab$gew_reported[nrow(tab)] / tab$gew_reported[1] - 1)))
print(tab)
