# Fog days per five-year period. This is the figure your claim rests on.
#
# It is deliberately the naive version: a rate over the rows that reported `nebel`. Run it, look at
# it, and then decide what you are going to do about the fact that it is defensible and misleading
# at the same time.
#
# Everything you write goes in out/. Nothing else is recorded as an output.

# This script finds its own directory, so it runs the same whether you call it from the repo root
# (which is what the cockpit does inside the container) or from the run folder (which is what
# RStudio does). Leave these three lines alone and everything below can use plain relative paths.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year   <- as.integer(substr(d$time, 1, 4))
d$period <- paste0(d$year - (d$year %% 5), "-", d$year - (d$year %% 5) + 4)

fog <- d[!is.na(d$nebel) & d$station %in% c(80,105), ]   # dave: the two complete stations
agg <- aggregate(cbind(days = nebel) ~ period, data = fog,
                 FUN = function(x) round(100 * mean(x > 0), 2))
names(agg)[2] <- "fog_day_pct"

dir.create("out", showWarnings = FALSE)
write.csv(agg, "out/fog-by-period.csv", row.names = FALSE)

png("out/fog-by-period.png", width = 900, height = 520)
barplot(agg$fog_day_pct, names.arg = agg$period, las = 2,
        ylab = "fog days (% of reporting station-days)",
        main = "Fog days in Austria, 1990-2025")
dev.off()

cat("wrote out/fog-by-period.csv and out/fog-by-period.png\n")
print(agg)
