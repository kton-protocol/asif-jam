# bob-f10 — THE DECOMPOSITION. How much of the naive decline is the denominator?
#
# Four series, one axis, each indexed to its own 1990-1994 value = 100:
#
#   naive rate          the starter's figure: fog days / station-days that reported nebel
#   panel rate          bob-f3: same, restricted to complete station-years on a fixed panel
#   count per station-  bob-f7: an integer numerator over an integer denominator
#     year
#   gew panel rate      bob-f4: the control indicator on the same rows
#
# If naive and panel land in the same place, composition is not doing the work. If gew
# lands there too, then nothing about this is specific to fog, and the claim is dead.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year <= 2024, ]
blocks <- seq(1990, 2020, by = 5)
d$block <- blocks[findInterval(d$year, blocks)]
d$period <- paste0(d$block, "-", d$block + 4)

# --- naive, exactly the starter's denominator
nv <- d[!is.na(d$nebel), ]
naive <- aggregate(cbind(fog = nv$nebel > 0, n = rep(1, nrow(nv))),
                   by = list(period = nv$period), FUN = sum)
naive$rate <- 100 * naive$fog / naive$n

# --- fixed panel of complete station-years
cnt  <- aggregate(list(days = nv$nebel), by = list(station = nv$station, year = nv$year), FUN = length)
fogd <- aggregate(list(fogd = nv$nebel > 0), by = list(station = nv$station, year = nv$year), FUN = sum)
cell <- merge(cnt, fogd, by = c("station", "year"))
cell <- cell[cell$days >= 350, ]
cell$block <- blocks[findInterval(cell$year, blocks)]
panel <- names(which(tapply(cell$block, cell$station,
                            function(b) length(unique(b)) == length(blocks))))
cell <- cell[cell$station %in% panel, ]
keep <- merge(nv, cell[, c("station", "year")], by = c("station", "year"))

pan <- aggregate(cbind(fog = keep$nebel > 0, n = rep(1, nrow(keep))),
                 by = list(period = keep$period), FUN = sum)
pan$rate <- 100 * pan$fog / pan$n

cy <- aggregate(cbind(fogd = cell$fogd, cells = rep(1, nrow(cell))),
                by = list(period = paste0(cell$block, "-", cell$block + 4)), FUN = sum)
cy$rate <- cy$fogd / cy$cells

kg <- keep[!is.na(keep$gew), ]
gw <- aggregate(cbind(storm = kg$gew > 0, n = rep(1, nrow(kg))),
                by = list(period = kg$period), FUN = sum)
gw$rate <- 100 * gw$storm / gw$n

periods <- sort(unique(naive$period))
idx <- function(df) { v <- df$rate[match(periods, df$period)]; 100 * v / v[1] }
out <- data.frame(period = periods,
                  naive_rate      = round(naive$rate[match(periods, naive$period)], 2),
                  panel_rate      = round(pan$rate[match(periods, pan$period)], 2),
                  fogdays_per_cell= round(cy$rate[match(periods, cy$period)], 2),
                  gew_panel_rate  = round(gw$rate[match(periods, gw$period)], 2),
                  naive_index     = round(idx(naive), 1),
                  panel_index     = round(idx(pan), 1),
                  count_index     = round(idx(cy), 1),
                  gew_index       = round(idx(gw), 1))

dir.create("out", showWarnings = FALSE)
write.csv(out, "out/decomposition-index.csv", row.names = FALSE)

png("out/decomposition-index.png", width = 1000, height = 560)
par(mar = c(6, 5, 4, 2))
ys <- as.matrix(out[, c("naive_index", "panel_index", "count_index", "gew_index")])
cols <- c("grey45", "#1f4e79", "#4f6228", "#c0504d")
matplot(seq_along(periods), ys, type = "b", pch = c(1, 19, 15, 17), lty = c(3, 1, 1, 2),
        lwd = c(2, 3, 3, 3), col = cols, xaxt = "n", ylim = c(0, 115),
        xlab = "", ylab = "index, 1990-1994 = 100",
        main = "Four ways of counting the same fog")
axis(1, at = seq_along(periods), labels = periods, las = 2)
abline(h = 100, col = "grey70")
abline(h = 100 * 2 / 3, lty = 2, col = "grey70")
text(1, 100 * 2 / 3 + 3, '"down by a third"', col = "grey40", cex = 0.85, pos = 4)
legend("bottomleft", bty = "n", lwd = 3, pch = c(1, 19, 15, 17), lty = c(3, 1, 1, 2), col = cols,
       legend = c("naive rate (starter)", "fixed-panel rate",
                  "fog days per station-year", "gew on the same rows"))
dev.off()

print(out)
n <- nrow(out)
for (k in c("naive_index", "panel_index", "count_index", "gew_index"))
  cat(sprintf("%-14s 1990-94 = 100  ->  2020-24 = %.1f  (%+.1f%%)\n",
              k, out[[k]][n], out[[k]][n] - 100))
