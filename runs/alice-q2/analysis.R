# Earthquakes per year, magnitude 3 and above. The naive count.
# This script finds its own directory, so it runs the same whether you call it from the repo root
# (which is what the cockpit does inside the container) or from the run folder (which is what
# RStudio does). Leave these three lines alone and everything below can use plain relative paths.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/quakes.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[!is.na(d$year) & !is.na(d$mag), ]

# THE ONE-LINE CHANGE. Restrict to events reported on the moment-magnitude scale (mw*) -- the
# modern, physically meaningful measure of energy release, as opposed to the older local/duration
# magnitudes. Nothing else in this script differs from alice-q1.
d <- d[grepl("^mw", d$magType), ]

agg <- as.data.frame(table(year = d$year), stringsAsFactors = FALSE)
names(agg) <- c("year", "quakes")
agg$year <- as.integer(agg$year)

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/quakes-mw-per-year.csv", row.names = FALSE)

png("out/quakes-mw-per-year.png", width = 900, height = 520)
plot(agg$year, agg$quakes, type = "l", lwd = 2,
     xlab = "year", ylab = "earthquakes M3+ recorded",
     main = "Recorded M3+ earthquakes on the moment-magnitude scale, per year")
dev.off()

cat("wrote out/quakes-mw-per-year.csv and out/quakes-mw-per-year.png\n")
