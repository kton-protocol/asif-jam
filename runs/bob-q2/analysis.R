# Earthquakes per year, magnitude 4 and above. The completeness-corrected count.
# This script finds its own directory, so it runs the same whether you call it from the repo root
# (which is what the cockpit does inside the container) or from the run folder (which is what
# RStudio does). Leave these three lines alone and everything below can use plain relative paths.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/quakes.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[!is.na(d$year) & !is.na(d$mag), ]
# ONE CHANGE from bob-q1: restrict to M4+, a magnitude California has been
# instrumentally complete for since long before 1970. Nothing else differs.
d <- d[d$mag >= 4, ]

agg <- as.data.frame(table(year = d$year), stringsAsFactors = FALSE)
names(agg) <- c("year", "quakes")
agg$year <- as.integer(agg$year)

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/quakes-per-year-m4.csv", row.names = FALSE)

png("out/quakes-per-year-m4.png", width = 900, height = 520)
plot(agg$year, agg$quakes, type = "l", lwd = 2,
     xlab = "year", ylab = "earthquakes M4+ recorded",
     main = "Recorded earthquakes M4+ per year")
dev.off()

cat("wrote out/quakes-per-year-m4.csv and out/quakes-per-year-m4.png\n")
