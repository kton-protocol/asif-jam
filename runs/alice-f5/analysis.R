# alice-f5 -- fog days per thunderstorm day, on the unbroken-record panel.
#
# If observers at these stations simply became less inclined to write anything down, both series
# fall together and this RATIO stays flat. If fog specifically declined, the ratio falls. The ratio
# is therefore the sharpest single test of my own claim that this file supports, so it is recorded
# whichever way it comes out.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year   <- as.integer(substr(d$time, 1, 4))
d$month  <- as.integer(substr(d$time, 6, 7))
d$period <- paste0(d$year - (d$year %% 5), "-", d$year - (d$year %% 5) + 4)
dir.create("out", showWarnings = FALSE)

rep  <- aggregate(list(n = !is.na(d$nebel)), by = list(station = d$station, year = d$year), FUN = sum)
good <- aggregate(list(fullyears = rep$n >= 350), by = list(station = rep$station), FUN = sum)
panel <- good$station[good$fullyears == length(unique(d$year))]
p <- d[d$station %in% panel, ]
cat("panel:", paste(sort(panel), collapse = ", "), "\n")

agg <- aggregate(cbind(fog = nebel, storm = gew) ~ period, data = p,
                 FUN = function(x) sum(x > 0, na.rm = TRUE))
agg$ratio <- round(agg$fog / agg$storm, 3)
write.csv(agg, "out/fog-per-storm-by-period.csv", row.names = FALSE)

png("out/fog-per-storm-by-period.png", width = 900, height = 520)
plot(seq_along(agg$period), agg$ratio, type = "b", pch = 19, lwd = 2, xaxt = "n",
     ylim = c(0, max(agg$ratio) * 1.2), xlab = "", ylab = "fog days per thunderstorm day",
     main = "Fog days divided by thunderstorm days, unbroken-record stations")
axis(1, at = seq_along(agg$period), labels = agg$period, las = 2)
abline(h = agg$ratio[1], col = "red", lty = 2)
dev.off()
print(agg)
cat("wrote out/fog-per-storm-by-period.csv and .png\n")
