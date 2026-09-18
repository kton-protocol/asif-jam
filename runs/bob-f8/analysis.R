# bob-f8 — "ON TRACK TO DISAPPEAR". The extrapolation, and its own refutation.
#
# This is the rhetorical step in the claim, so it gets drawn honestly enough that anyone
# can see what it is. Two fits to fog days per complete station-year on the fixed panel:
#
#   linear  -- extended to the x-intercept. This is the number the headline wants.
#   log-linear (Poisson-style constant proportional decline) -- which never reaches zero.
#
# The two fit the SAME 35 observations about equally well and disagree completely about
# 2100. That disagreement is the whole content of the word "disappear".
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
blocks <- seq(1990, 2020, by = 5)
cell$block <- blocks[findInterval(cell$year, blocks)]
panel <- names(which(tapply(cell$block, cell$station,
                            function(b) length(unique(b)) == length(blocks))))
cell <- cell[cell$station %in% panel, ]

yr <- aggregate(cbind(fog_days = cell$fog, n = rep(1, nrow(cell))),
                by = list(year = cell$year), FUN = sum)
yr$per_station_year <- yr$fog_days / yr$n
yr <- yr[order(yr$year), ]

lin <- lm(per_station_year ~ year, data = yr)
b0 <- coef(lin)[1]; b1 <- coef(lin)[2]
zero_year <- as.numeric(-b0 / b1)
ci <- confint(lin)["year", ]
zero_lo <- as.numeric(-b0 / ci[1])   # steepest slope -> earliest zero
zero_hi <- as.numeric(-b0 / ci[2])   # shallowest slope -> latest zero

logfit <- lm(log(per_station_year) ~ year, data = yr)
halflife <- as.numeric(log(0.5) / coef(logfit)["year"])

fut <- data.frame(year = 1990:2100)
fut$lin <- predict(lin, fut)
fut$exp <- exp(predict(logfit, fut))

tab <- data.frame(
  model            = c("linear", "log-linear"),
  slope_per_year   = c(round(b1, 4), round(coef(logfit)["year"], 5)),
  r_squared        = c(round(summary(lin)$r.squared, 3), round(summary(logfit)$r.squared, 3)),
  value_2050       = round(c(fut$lin[fut$year == 2050], fut$exp[fut$year == 2050]), 2),
  value_2100       = round(c(fut$lin[fut$year == 2100], fut$exp[fut$year == 2100]), 2),
  reaches_zero_in  = c(round(zero_year, 1), NA)
)

dir.create("out", showWarnings = FALSE)
write.csv(yr,  "out/fog-annual-panel.csv", row.names = FALSE)
write.csv(tab, "out/extrapolation-models.csv", row.names = FALSE)

png("out/fog-extrapolation.png", width = 1000, height = 560)
par(mar = c(5, 5, 4, 2))
plot(yr$year, yr$per_station_year, pch = 19, col = "#1f4e79",
     xlim = c(1990, 2100), ylim = c(0, max(yr$per_station_year) * 1.1),
     xlab = "year", ylab = "fog days per complete station-year",
     main = "Two fits to the same 35 points")
lines(fut$year, pmax(fut$lin, 0), lwd = 3, col = "#c0504d")
lines(fut$year, fut$exp,          lwd = 3, col = "#4f6228", lty = 2)
abline(h = 0, col = "grey60")
points(zero_year, 0, pch = 4, cex = 2, lwd = 3, col = "#c0504d")
text(zero_year, max(yr$per_station_year) * 0.12,
     sprintf("linear fit hits zero\nin %.0f", zero_year), col = "#c0504d", cex = 0.9)
legend("topright", bty = "n", lwd = 3, lty = c(1, 2), col = c("#c0504d", "#4f6228"),
       legend = c("linear: fog is abolished", "log-linear: fog halves and halves again"))
dev.off()

cat(sprintf("linear: %.3f days/year, zero in %.0f (95%% CI %.0f to %.0f)\n",
            b1, zero_year, zero_lo, zero_hi))
cat(sprintf("log-linear: half-life %.0f years, never zero; 2100 value %.2f days\n",
            halflife, fut$exp[fut$year == 2100]))
print(tab)
