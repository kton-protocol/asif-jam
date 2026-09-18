# bob-f11 — CAROL IS RIGHT AND MY SIGN TEST IS WEAKER THAN I SAID.
#
# bob-f6 reported "7 of 7 panel stations decline, sign test p = 0.0078". carol-f8 fits all
# TEN stations and finds two with positive slopes -- stations 20 (+0.668 pp/yr) and 170
# (+0.370 pp/yr). Those two are precisely the stations my panel rule threw out, because
# they stop reporting in 2007 and 2013.
#
# So my unanimity may be selection. This run settles it the only fair way: fit every
# station on the COMMON window in which all ten report, instead of on each station's own
# window. Whatever the answer is, it is in the record next to bob-f6.
#
#   panel A  all 10 stations, common window (the widest window all ten cover)
#   panel B  my bob-f6 panel, same common window, for comparability
#   panel C  my bob-f6 panel on the full 1990-2024 window (reproduces bob-f6)
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year <= 2024, ]

rep  <- d[!is.na(d$nebel), ]
cnt  <- aggregate(list(days = rep$nebel), by = list(station = rep$station, year = rep$year), FUN = length)
fogd <- aggregate(list(fog = rep$nebel > 0), by = list(station = rep$station, year = rep$year), FUN = sum)
cell <- merge(cnt, fogd, by = c("station", "year"))
cell <- cell[cell$days >= 350, ]
cell$fog_pct <- 100 * cell$fog / cell$days

# widest window covered by EVERY station that has any complete year at all
stations <- sort(unique(cell$station))
lo <- max(sapply(stations, function(s) min(cell$year[cell$station == s])))
hi <- min(sapply(stations, function(s) max(cell$year[cell$station == s])))
cat(sprintf("common window in which all %d stations have complete years: %d-%d\n",
            length(stations), lo, hi))

blocks <- seq(1990, 2020, by = 5)
cell$block <- blocks[findInterval(cell$year, blocks)]
panel <- as.integer(names(which(tapply(cell$block, cell$station,
                                       function(b) length(unique(b)) == length(blocks)))))

slopes <- function(cc, label) {
  ss <- sort(unique(cc$station))
  r <- do.call(rbind, lapply(ss, function(s) {
    x <- cc[cc$station == s, ]
    if (nrow(x) < 5) return(NULL)
    m <- lm(fog_pct ~ year, data = x)
    data.frame(panel = label, station = s, years = nrow(x),
               from = min(x$year), to = max(x$year),
               slope_pp_per_year = round(coef(m)["year"], 4),
               p_value = signif(summary(m)$coefficients["year", 4], 3))
  }))
  r
}

A <- slopes(cell[cell$year >= lo & cell$year <= hi, ], sprintf("all-10 %d-%d", lo, hi))
B <- slopes(cell[cell$station %in% panel & cell$year >= lo & cell$year <= hi, ],
            sprintf("bob-f6 panel %d-%d", lo, hi))
C <- slopes(cell[cell$station %in% panel, ], "bob-f6 panel 1990-2024")
res <- rbind(A, B, C)

summ <- do.call(rbind, lapply(unique(res$panel), function(p) {
  x <- res[res$panel == p, ]
  k <- nrow(x); dn <- sum(x$slope_pp_per_year < 0)
  data.frame(panel = p, stations = k, negative = dn,
             sign_test_p = signif(if (dn == k) 2^(-k) else
               binom.test(dn, k, 0.5, alternative = "greater")$p.value, 3),
             median_slope = round(median(x$slope_pp_per_year), 4))
}))

dir.create("out", showWarnings = FALSE)
write.csv(res,  "out/common-window-slopes.csv", row.names = FALSE)
write.csv(summ, "out/common-window-summary.csv", row.names = FALSE)

png("out/common-window-slopes.png", width = 1000, height = 560)
par(mar = c(5, 6, 4, 2))
cols <- c("#c0504d", "#1f4e79", "#4f6228")
pn <- unique(res$panel)
plot(NA, xlim = range(res$slope_pp_per_year) * 1.1,
     ylim = c(0.5, nrow(res) + 0.5), yaxt = "n",
     xlab = "slope of fog-day rate, percentage points per year", ylab = "",
     main = "Does every station fall? Depends which stations, on which years")
i <- 0
for (k in seq_along(pn)) {
  x <- res[res$panel == pn[k], ]
  x <- x[order(x$slope_pp_per_year), ]
  for (j in seq_len(nrow(x))) {
    i <- i + 1
    points(x$slope_pp_per_year[j], i, pch = 19, cex = 1.3, col = cols[k])
    axis(2, at = i, labels = sprintf("%s  st.%s", pn[k], x$station[j]), las = 2, cex.axis = 0.65)
  }
}
abline(v = 0, lty = 2, col = "grey40")
dev.off()

print(summ)
print(res)
