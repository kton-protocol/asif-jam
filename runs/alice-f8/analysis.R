# alice-f8 -- every station drawn separately, including the ones that stop.
#
# One panel per station, fog-day rate per year, with the years a station reported fewer than 350
# days marked. Nothing is aggregated away: a reader can see which stations carry the headline
# decline and which stations simply leave the file.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year   <- as.integer(substr(d$time, 1, 4))
d$month  <- as.integer(substr(d$time, 6, 7))
d$period <- paste0(d$year - (d$year %% 5), "-", d$year - (d$year %% 5) + 4)
dir.create("out", showWarnings = FALSE)

sy <- aggregate(list(reported = !is.na(d$nebel)), by = list(station = d$station, year = d$year), FUN = sum)
fg <- aggregate(list(fog_days = d$nebel > 0), by = list(station = d$station, year = d$year),
                FUN = function(x) sum(x, na.rm = TRUE))
sy <- merge(sy, fg, by = c("station", "year"))
sy$fog_day_pct <- ifelse(sy$reported > 0, round(100 * sy$fog_days / sy$reported, 2), NA)
sy$partial <- sy$reported < 350
sy <- sy[order(as.integer(sy$station), sy$year), ]
write.csv(sy, "out/fog-by-station-year.csv", row.names = FALSE)

st <- sort(unique(as.integer(sy$station)))
png("out/fog-by-station-year.png", width = 1100, height = 760)
par(mfrow = c(4, 3), mar = c(3, 4, 2.5, 1))
for (s in st) {
  x <- sy[as.integer(sy$station) == s, ]
  plot(x$year, x$fog_day_pct, type = "n", ylim = c(0, 25), xlim = c(1990, 2025),
       xlab = "", ylab = "fog days %", main = paste("station", s))
  ok <- x[!x$partial, ]; bad <- x[x$partial, ]
  lines(ok$year, ok$fog_day_pct, lwd = 2)
  points(ok$year, ok$fog_day_pct, pch = 19, cex = 0.6)
  points(bad$year, ifelse(is.na(bad$fog_day_pct), 0, bad$fog_day_pct), pch = 4, col = "red")
  if (nrow(ok) > 2) abline(lm(fog_day_pct ~ year, data = ok), col = "blue", lty = 2)
}
plot.new(); legend("center", c("full year (>=350 d)", "partial / absent", "OLS on full years"),
                   pch = c(19, 4, NA), lty = c(NA, NA, 2), col = c("black", "red", "blue"), bty = "n")
dev.off()
cat("stations:", paste(st, collapse = ", "), "\n")
cat("wrote out/fog-by-station-year.csv and .png\n")
