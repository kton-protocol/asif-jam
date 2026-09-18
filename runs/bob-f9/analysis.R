# bob-f9 — HOW MUCH OF THE HEADLINE IS THE HEADLINE'S OWN CHOICES?
#
# bob-f3 reports -38.1%, but it made four arbitrary decisions to get there:
# the completeness threshold (350 days), the panel rule, the start year, and
# whether 2025 is in. Vary all four, report every combination, and show the
# whole distribution instead of the one number I liked.
#
# Also leave each panel station out in turn, because station 131 is the foggiest
# AND the steepest, and one station should not be carrying a national claim.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d0 <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d0$year <- as.integer(substr(d0$time, 1, 4))

pct_change <- function(thresh, start, end, drop_station = NA) {
  d <- d0[d0$year >= start & d0$year <= end, ]
  rep  <- d[!is.na(d$nebel), ]
  if (!is.na(drop_station)) rep <- rep[rep$station != drop_station, ]
  if (!nrow(rep)) return(NULL)
  cnt  <- aggregate(list(days = rep$nebel), by = list(station = rep$station, year = rep$year),
                    FUN = length)
  fogd <- aggregate(list(fog = rep$nebel > 0), by = list(station = rep$station, year = rep$year),
                    FUN = sum)
  cell <- merge(cnt, fogd, by = c("station", "year"))
  cell <- cell[cell$days >= thresh, ]
  if (!nrow(cell)) return(NULL)
  blocks <- seq(start, end - 4, by = 5)
  cell$block <- blocks[findInterval(cell$year, blocks)]
  cell <- cell[!is.na(cell$block), ]
  panel <- names(which(tapply(cell$block, cell$station,
                              function(b) length(unique(b)) == length(blocks))))
  if (length(panel) < 2) return(NULL)
  cell <- cell[cell$station %in% panel, ]
  agg <- aggregate(cbind(fog = cell$fog, days = cell$days), by = list(block = cell$block), FUN = sum)
  agg <- agg[order(agg$block), ]
  r <- 100 * agg$fog / agg$days
  data.frame(threshold = thresh, start = start, end = end,
             dropped = ifelse(is.na(drop_station), "none", as.character(drop_station)),
             stations = length(panel),
             first_pct = round(r[1], 2), last_pct = round(r[length(r)], 2),
             change_pct = round(100 * (r[length(r)] / r[1] - 1), 1))
}

grid <- list()
for (th in c(300, 330, 350, 365))
  for (st in c(1990, 1995, 2000))
    for (en in c(2024, 2025))
      grid[[length(grid) + 1]] <- pct_change(th, st, en)
spec <- do.call(rbind, grid)

# leave-one-station-out at the headline specification
stations <- sort(unique(d0$station))
loo <- do.call(rbind, lapply(stations, function(s) pct_change(350, 1990, 2024, s)))

dir.create("out", showWarnings = FALSE)
write.csv(spec, "out/specification-grid.csv", row.names = FALSE)
write.csv(loo,  "out/leave-one-station-out.csv", row.names = FALSE)

png("out/specification-grid.png", width = 1000, height = 560)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
o <- order(spec$change_pct)
plot(spec$change_pct[o], seq_len(nrow(spec)), pch = 19, col = "#1f4e79",
     xlab = "change in fog rate, first block to last (%)", ylab = "specification (sorted)",
     main = sprintf("%d specifications", nrow(spec)))
abline(v = 0, lty = 2, col = "grey40")
abline(v = -38.1, lty = 3, col = "#c0504d", lwd = 2)
text(-38.1, nrow(spec) * 0.1, " the one I reported", col = "#c0504d", cex = 0.8, pos = 4)

o2 <- order(loo$change_pct)
plot(loo$change_pct[o2], seq_len(nrow(loo)), pch = 19, col = "#4f6228", yaxt = "n",
     xlab = "change in fog rate (%)", ylab = "",
     main = "leave one station out")
axis(2, at = seq_len(nrow(loo)), labels = paste("-", loo$dropped[o2]), las = 2, cex.axis = 0.8)
abline(v = 0, lty = 2, col = "grey40")
abline(v = -38.1, lty = 3, col = "#c0504d", lwd = 2)
dev.off()

cat(sprintf("specifications: n=%d  median %.1f%%  range %.1f%% to %.1f%%  negative in %d\n",
            nrow(spec), median(spec$change_pct), min(spec$change_pct), max(spec$change_pct),
            sum(spec$change_pct < 0)))
cat(sprintf("leave-one-out:  n=%d  range %.1f%% to %.1f%%\n",
            nrow(loo), min(loo$change_pct), max(loo$change_pct)))
print(spec)
print(loo)
