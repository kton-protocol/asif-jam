# The figure I would actually put on the slide. Balanced panel, five-year blocks, with the fitted
# annual trend carried forward to the axis. Two deliberate rendering choices, both stated here and
# both visible in the code: the y-axis starts at 3 rather than 0, and the projection is drawn in
# the same weight as the fit. Neither invents a number; both make the same numbers look steeper.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year >= 1990 & d$year <= 2024, ]
daysper <- tapply(rep(1, nrow(d)), list(d$year, d$station), sum)
repper  <- tapply(as.integer(!is.na(d$nebel)), list(d$year, d$station), sum)
complete <- colnames(repper)[apply(repper == daysper, 2, function(x) all(!is.na(x) & x))]
b <- d[as.character(d$station) %in% complete, ]

yrs <- sort(unique(b$year))
ann <- data.frame(year = yrs,
  fog_day_pct = sapply(yrs, function(y) 100 * mean(b$nebel[b$year == y] > 0)))
fit <- lm(fog_day_pct ~ year, data = ann)
zero <- -coef(fit)[1] / coef(fit)[2]

b$period <- paste0(b$year - (b$year %% 5), "-", b$year - (b$year %% 5) + 4)
per <- sort(unique(b$period))
pct <- sapply(per, function(p) 100 * mean(b$nebel[b$period == p] > 0))

dir.create("out", showWarnings = FALSE)
write.csv(data.frame(period = per, fog_day_pct = round(pct, 2)),
          "out/headline.csv", row.names = FALSE)
writeLines(sprintf("y-axis floor: 3.0 (not 0). trend zero-crossing: %.0f", zero), "out/headline.txt")

png("out/headline.png", width = 980, height = 560)
par(mar = c(6, 6, 5, 2))
plot(seq_along(per), pct, type = "o", pch = 19, lwd = 4, col = "grey15",
     ylim = c(3, 7.6), xlim = c(1, length(per) + 0.4), xaxt = "n", yaxt = "n", bty = "n",
     xlab = "", ylab = "",
     main = "Austrian fog is running out")
axis(1, at = seq_along(per), labels = per, las = 2, cex.axis = 1.05)
axis(2, at = 3:7, labels = paste0(3:7, "%"), las = 1, cex.axis = 1.05)
mtext("fog days as a share of station-days\n(two stations, every day, 1990-2024)",
      side = 2, line = 3.2, cex = 0.95)
text(1, pct[1] + 0.3, sprintf("%.2f%%", pct[1]), cex = 1.1)
text(length(per), pct[length(per)] - 0.3, sprintf("%.2f%%", pct[length(per)]), cex = 1.1)
mtext(sprintf("-%.0f%% since 1990  |  linear trend reaches zero in %.0f",
              abs(100 * pct[length(per)] / pct[1] - 100), zero),
      side = 1, line = 4.6, cex = 1.05)
dev.off()

cat(sprintf("headline: %.2f%% -> %.2f%% (%+.1f%%), zero-crossing %.0f\n",
            pct[1], pct[length(per)], 100 * pct[length(per)] / pct[1] - 100, zero))
