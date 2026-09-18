# bob-f6 — EVERY STATION IS ITS OWN CONTROL.
#
# The composition objection ("different stations in different years") cannot touch a
# within-station comparison. For each panel station, fit fog_days_per_complete_year on
# year by OLS, and report the slope. A composition artefact would have no reason to
# point the same way at every station; a real regional change would.
#
# Also does the exact sign test: P(all k slopes negative | coin flips) = 2^-k.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d$year <- as.integer(substr(d$time, 1, 4))
d <- d[d$year <= 2024, ]

rep  <- d[!is.na(d$nebel), ]
cnt  <- aggregate(list(days = rep$nebel), by = list(station = rep$station, year = rep$year),
                  FUN = length)
fogd <- aggregate(list(fog = rep$nebel > 0), by = list(station = rep$station, year = rep$year),
                  FUN = sum)
cell <- merge(cnt, fogd, by = c("station", "year"))
cell <- cell[cell$days >= 350, ]
cell$fog_pct <- 100 * cell$fog / cell$days

blocks <- seq(1990, 2020, by = 5)
cell$block <- blocks[findInterval(cell$year, blocks)]
panel <- names(which(tapply(cell$block, cell$station,
                            function(b) length(unique(b)) == length(blocks))))
cell <- cell[cell$station %in% panel, ]

res <- do.call(rbind, lapply(sort(as.integer(panel)), function(s) {
  x <- cell[cell$station == s, ]
  m <- lm(fog_pct ~ year, data = x)
  ci <- confint(m)["year", ]
  data.frame(station = s, years = nrow(x),
             first_year = min(x$year), last_year = max(x$year),
             mean_fog_pct = round(mean(x$fog_pct), 2),
             slope_pct_per_decade = round(10 * coef(m)["year"], 3),
             ci_lo_per_decade = round(10 * ci[1], 3),
             ci_hi_per_decade = round(10 * ci[2], 3),
             p_value = signif(summary(m)$coefficients["year", 4], 3))
}))

k    <- nrow(res)
down <- sum(res$slope_pct_per_decade < 0)
sign_p <- 2 ^ (-k)

dir.create("out", showWarnings = FALSE)
write.csv(res, "out/per-station-slopes.csv", row.names = FALSE)

png("out/per-station-slopes.png", width = 900, height = 520)
par(mar = c(5, 6, 4, 2))
ord <- order(res$slope_pct_per_decade)
r <- res[ord, ]
xl <- range(c(r$ci_lo_per_decade, r$ci_hi_per_decade, 0))
plot(r$slope_pct_per_decade, seq_len(k), pch = 19, cex = 1.4, col = "#1f4e79",
     xlim = xl, ylim = c(0.5, k + 0.5), yaxt = "n",
     xlab = "change in fog-day rate, percentage points per decade",
     ylab = "", main = sprintf("Every station falls (%d of %d), 1990-2024", down, k))
segments(r$ci_lo_per_decade, seq_len(k), r$ci_hi_per_decade, seq_len(k), lwd = 2, col = "#1f4e79")
axis(2, at = seq_len(k), labels = paste("station", r$station), las = 2)
abline(v = 0, lty = 2, col = "grey40")
dev.off()

cat(sprintf("%d of %d panel stations have a negative slope; exact sign-test p = %.4f\n",
            down, k, sign_p))
print(res)
