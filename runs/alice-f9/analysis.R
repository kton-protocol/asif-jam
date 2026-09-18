# alice-f9 -- how much of the "fog season" decline is October and March?
#
# Builds directly on carol-f7 (sha256:78fabee43aeb...), which restricts to an Oct-Mar winter on the
# balanced panel and reports 11.14% (1990-94) -> 7.41% (2020-24), -33.5%. My own alice-f6
# (sha256:b7edcae2f010...) found the deep-winter months nearly flat. Both are true; this run shows
# why, by giving every calendar month its own OLS slope over the same panel, with its own counts.
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

res <- do.call(rbind, lapply(1:12, function(mm) {
  x  <- p[p$month == mm, ]
  yr <- aggregate(cbind(fog = nebel) ~ year, data = x, FUN = function(v) sum(v > 0))
  yr$n <- aggregate(cbind(n = nebel) ~ year, data = x, FUN = length)$n
  yr$pct <- 100 * yr$fog / yr$n
  f <- lm(pct ~ year, data = yr); s <- summary(f)$coefficients
  data.frame(month = mm, month_name = month.abb[mm],
             fog_days_total = sum(yr$fog),
             mean_pct = round(mean(yr$pct), 2),
             slope_pp_per_yr = round(s[2, 1], 4),
             p_value = signif(s[2, 4], 3),
             pct_1990s = round(100 * sum(yr$fog[yr$year <= 1999]) / sum(yr$n[yr$year <= 1999]), 2),
             pct_2016p = round(100 * sum(yr$fog[yr$year >= 2016]) / sum(yr$n[yr$year >= 2016]), 2))
}))
res$change_pct <- round(100 * res$pct_2016p / res$pct_1990s - 100, 1)
write.csv(res, "out/fog-month-slopes.csv", row.names = FALSE)

png("out/fog-month-slopes.png", width = 1000, height = 560)
par(mar = c(4, 4.5, 3, 4.5))
cols <- ifelse(res$p_value < 0.05, "grey20", "grey75")
bp <- barplot(res$slope_pp_per_yr, names.arg = month.abb, col = cols,
        ylab = "OLS slope in fog-day % per year", main =
        "Fog trend by calendar month, unbroken-record stations (dark = p < 0.05)")
par(new = TRUE)
plot(bp, res$fog_days_total, type = "b", pch = 19, col = "red", axes = FALSE, xlab = "", ylab = "")
axis(4, col = "red", col.axis = "red"); mtext("total fog days 1990-2025", 4, line = 3, col = "red")
dev.off()
print(res)
cat("wrote out/fog-month-slopes.csv and .png\n")
