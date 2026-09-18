# alice-f6 -- where in the year the decline actually is.
#
# Fog is a cold-season phenomenon; thunderstorms are a warm-season one. A headline annual rate mixes
# the season that carries the signal with eleven months of near-zero counts. This splits both
# series by calendar month, first decade (1990-1999) against last decade (2016-2025), on the
# unbroken-record panel. It is the figure most likely to damage my own headline, which is why it
# is in the record.
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
p$era <- ifelse(p$year <= 1999, "1990-1999", ifelse(p$year >= 2016, "2016-2025", NA))
p <- p[!is.na(p$era), ]

m <- aggregate(cbind(fog = nebel, storm = gew) ~ month + era, data = p,
               FUN = function(x) sum(x > 0, na.rm = TRUE))
out <- data.frame(month = 1:12)
out$fog_1990s   <- m$fog[m$era == "1990-1999"][match(out$month, m$month[m$era == "1990-1999"])]
out$fog_2016_25 <- m$fog[m$era == "2016-2025"][match(out$month, m$month[m$era == "2016-2025"])]
out$storm_1990s   <- m$storm[m$era == "1990-1999"][match(out$month, m$month[m$era == "1990-1999"])]
out$storm_2016_25 <- m$storm[m$era == "2016-2025"][match(out$month, m$month[m$era == "2016-2025"])]
out$fog_change_pct   <- round(100 * out$fog_2016_25 / out$fog_1990s - 100, 1)
out$storm_change_pct <- round(100 * out$storm_2016_25 / out$storm_1990s - 100, 1)
write.csv(out, "out/fog-storm-by-month.csv", row.names = FALSE)

png("out/fog-storm-by-month.png", width = 1000, height = 620)
par(mfrow = c(2, 1), mar = c(3, 4.5, 3, 1))
barplot(rbind(out$fog_1990s, out$fog_2016_25), beside = TRUE, names.arg = month.abb,
        col = c("grey30", "grey70"), ylab = "fog days (10 yr total)",
        main = "nebel by calendar month: 1990-1999 vs 2016-2025, unbroken-record stations")
legend("topright", c("1990-1999", "2016-2025"), fill = c("grey30", "grey70"), bty = "n")
barplot(rbind(out$storm_1990s, out$storm_2016_25), beside = TRUE, names.arg = month.abb,
        col = c("grey30", "grey70"), ylab = "thunderstorm days (10 yr total)",
        main = "gew by calendar month, same station-days")
dev.off()
print(out)
cat("wrote out/fog-storm-by-month.csv and .png\n")
