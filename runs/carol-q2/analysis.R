# The same count, one line different: magnitude 4 and above.
# M3 detection depends on how many seismometers were running. M4 in California was already
# fully detected in 1970. If the rise is instrumental it dies here; if it is the Earth it survives.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/quakes.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[!is.na(d$year) & !is.na(d$mag), ]
d <- d[d$mag >= 4, ]

agg <- as.data.frame(table(year = d$year), stringsAsFactors = FALSE)
names(agg) <- c("year", "quakes")
agg$year <- as.integer(agg$year)

fit <- lm(quakes ~ year, data = agg)
slope <- coef(fit)[["year"]]

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/quakes-per-year-m4.csv", row.names = FALSE)
writeLines(sprintf("M4+ slope: %.3f events/year (p = %.3f)",
                   slope, summary(fit)$coefficients["year", 4]),
           "out/m4-slope.txt")

png("out/quakes-per-year-m4.png", width = 900, height = 520)
plot(agg$year, agg$quakes, type = "l", lwd = 2,
     xlab = "year", ylab = "earthquakes M4+ recorded",
     main = "Recorded earthquakes M4+ per year (California)")
abline(fit, col = "red", lty = 2)
dev.off()

cat(sprintf("M4+ slope %.3f/yr\n", slope))
print(agg)
