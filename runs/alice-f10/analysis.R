# alice-f10 -- the headline number as a function of the window I chose to call "the fog season".
#
# A specification curve. Every contiguous month window from 1 to 12 months long, on the unbroken-
# record panel, each giving its own 1990-1994 -> 2020-2024 change. If the answer is stable across
# windows, the season choice is not doing the work. If it is not stable, the reader should see the
# whole surface rather than the one window an author picked.
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

wins <- list()
for (len in 1:12) for (start in 1:12) {
  ms <- ((start - 1 + seq_len(len) - 1) %% 12) + 1
  wins[[length(wins) + 1]] <- list(start = start, len = len, months = ms)
}
res <- do.call(rbind, lapply(wins, function(w) {
  x <- p[p$month %in% w$months, ]
  a <- x[x$year >= 1990 & x$year <= 1994, ]; z <- x[x$year >= 2020 & x$year <= 2024, ]
  ra <- 100 * sum(a$nebel > 0, na.rm = TRUE) / sum(!is.na(a$nebel))
  rz <- 100 * sum(z$nebel > 0, na.rm = TRUE) / sum(!is.na(z$nebel))
  data.frame(start_month = month.abb[w$start], length_months = w$len,
             window = paste(month.abb[w$months], collapse = ""),
             pct_1990_1994 = round(ra, 2), pct_2020_2024 = round(rz, 2),
             change_pct = round(100 * rz / ra - 100, 1),
             fog_days_1990_1994 = sum(a$nebel > 0, na.rm = TRUE))
}))
res <- res[order(res$change_pct), ]
write.csv(res, "out/fog-window-sensitivity.csv", row.names = FALSE)

png("out/fog-window-sensitivity.png", width = 1000, height = 600)
par(mar = c(5, 5, 3, 1))
plot(seq_len(nrow(res)), res$change_pct, pch = 19, cex = 0.7,
     col = ifelse(res$fog_days_1990_1994 >= 50, "black", "grey70"),
     xlab = "the 144 contiguous month-windows, sorted by the answer they give",
     ylab = "change in fog-day rate, 1990-1994 to 2020-2024 (%)",
     main = "Every 'fog season' I could have chosen, and the headline each one yields")
abline(h = 0, col = "grey40"); abline(h = -33.3, col = "red", lty = 2)
text(5, -30, "\"roughly a third\"", col = "red", pos = 4)
legend("topleft", c(">= 50 fog days in the baseline", "fewer (noise)"),
       pch = 19, col = c("black", "grey70"), bty = "n")
dev.off()
cat(sprintf("windows: %d; median change %.1f%%; range %.1f%% to %.1f%%\n",
    nrow(res), median(res$change_pct), min(res$change_pct), max(res$change_pct)))
big <- res[res$fog_days_1990_1994 >= 50, ]
cat(sprintf("of the %d windows with >=50 baseline fog days: median %.1f%%, range %.1f%% to %.1f%%\n",
    nrow(big), median(big$change_pct), min(big$change_pct), max(big$change_pct)))
print(head(res[res$fog_days_1990_1994 >= 50, ], 5))
print(tail(res[res$fog_days_1990_1994 >= 50, ], 5))
cat("wrote out/fog-window-sensitivity.csv and .png\n")
