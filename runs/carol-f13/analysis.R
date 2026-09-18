# Small multiples: every station, its own panel, its own reporting days, on a common axis.
# Grey shading marks the years a station did not report, so the reader can see attrition instead of
# being told about it. This is the same data as carol-f8, drawn instead of modelled.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year >= 1990 & d$year <= 2024, ]
sts <- sort(unique(d$station))
yrs <- 1990:2024

tab <- do.call(rbind, lapply(sts, function(s) {
  x <- d[d$station == s, ]
  data.frame(station = s, year = yrs,
    reporting = sapply(yrs, function(y) sum(x$year == y & !is.na(x$nebel))),
    fog_days  = sapply(yrs, function(y) sum(x$year == y & !is.na(x$nebel) & x$nebel > 0)),
    stringsAsFactors = FALSE)
}))
tab$fog_day_pct <- ifelse(tab$reporting >= 30, round(100 * tab$fog_days / tab$reporting, 2), NA)

dir.create("out", showWarnings = FALSE)
write.csv(tab, "out/station-year.csv", row.names = FALSE)

png("out/small-multiples.png", width = 1000, height = 700)
par(mfrow = c(4, 3), mar = c(3, 4, 2.5, 1), oma = c(2, 2, 3, 1))
for (s in sts) {
  x <- tab[tab$station == s, ]
  plot(x$year, x$fog_day_pct, type = "n", ylim = c(0, 30), xlim = range(yrs),
       xlab = "", ylab = "fog-day %", main = paste("station", s))
  gaps <- x$year[x$reporting < 30]
  if (length(gaps)) rect(gaps - 0.5, 0, gaps + 0.5, 30, col = "grey88", border = NA)
  lines(x$year, x$fog_day_pct, lwd = 2)
  ok <- !is.na(x$fog_day_pct)
  if (sum(ok) > 2) abline(lm(x$fog_day_pct[ok] ~ x$year[ok]), col = "red", lty = 2, lwd = 2)
  box()
}
plot.new()
legend("center", c("fog-day %", "least-squares trend", "not reporting"),
       lwd = c(2, 2, NA), lty = c(1, 2, NA), col = c("black", "red", NA),
       fill = c(NA, NA, "grey88"), border = NA, bty = "n")
mtext("Fog days per year, every station, 1990-2024", outer = TRUE, cex = 1.2, line = 0.5)
dev.off()

cat(sprintf("%d stations; station-years with >=30 reporting days: %d of %d\n",
            length(sts), sum(tab$reporting >= 30), nrow(tab)))
agg <- aggregate(reporting ~ station, tab, function(v) sum(v >= 30))
names(agg)[2] <- "years_reporting"
print(agg)
