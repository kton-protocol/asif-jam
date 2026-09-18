# A specification curve. Twelve defensible ways of asking "how much has fog fallen since 1990",
# each computed from the same file, each reported as the change from the first window to the last.
# The point of the figure is that the answer does not depend on which of them you pick.
a <- commandArgs(trailingOnly = FALSE)
here <- dirname(sub("^--file=", "", a[grep("^--file=", a)]))
if (length(here) == 1 && nzchar(here)) setwd(here)

d0 <- read.csv("inputs/fog-nebel-gew.csv", stringsAsFactors = FALSE)
d0$year  <- as.integer(substr(d0$time, 1, 4))
d0$month <- as.integer(substr(d0$time, 6, 7))

dd <- d0[d0$year >= 1990 & d0$year <= 2024, ]
daysper <- tapply(rep(1, nrow(dd)), list(dd$year, dd$station), sum)
repper  <- tapply(as.integer(!is.na(dd$nebel)), list(dd$year, dd$station), sum)
complete <- colnames(repper)[apply(repper == daysper, 2, function(x) all(!is.na(x) & x))]
longrun  <- colnames(repper)[apply(repper, 2, function(x) sum(!is.na(x) & x >= 300) >= 30)]

chg <- function(x, first, last, block) {
  # x already filtered; block = width of the end windows in years
  a <- x[x$year %in% first, ]; b <- x[x$year %in% last, ]
  ra <- 100 * mean(a$nebel[!is.na(a$nebel)] > 0)
  rb <- 100 * mean(b$nebel[!is.na(b$nebel)] > 0)
  c(first = round(ra, 2), last = round(rb, 2), pct_change = round(100 * rb / ra - 100, 1))
}
win5a <- 1990:1994; win5b <- 2020:2024
win10a <- 1990:1999; win10b <- 2015:2024

specs <- list(
  "all stations, 5y windows"          = chg(dd, win5a, win5b),
  "all stations, 10y windows"         = chg(dd, win10a, win10b),
  "balanced panel (80,105), 5y"       = chg(dd[as.character(dd$station) %in% complete, ], win5a, win5b),
  "balanced panel, 10y"               = chg(dd[as.character(dd$station) %in% complete, ], win10a, win10b),
  "stations with >=30 good years"     = chg(dd[as.character(dd$station) %in% longrun, ], win5a, win5b),
  "fog season Oct-Mar, all stations"  = chg(dd[dd$month %in% c(10,11,12,1,2,3), ], win5a, win5b),
  "fog season, balanced panel"        = chg(dd[dd$month %in% c(10,11,12,1,2,3) &
                                               as.character(dd$station) %in% complete, ], win5a, win5b),
  "Nov-Jan peak only, all stations"   = chg(dd[dd$month %in% c(11,12,1), ], win5a, win5b),
  "Nov-Jan peak, balanced panel"      = chg(dd[dd$month %in% c(11,12,1) &
                                               as.character(dd$station) %in% complete, ], win5a, win5b),
  "incl. partial 2025, all stations"  = chg(d0[d0$year >= 1990, ], win5a, 2021:2025),
  "summer Apr-Sep, all stations"      = chg(dd[dd$month %in% 4:9, ], win5a, win5b),
  "single wettest station (124)"      = chg(dd[dd$station == 124, ], win5a, win5b))

res <- data.frame(spec = names(specs), t(sapply(specs, identity)), stringsAsFactors = FALSE)
rownames(res) <- NULL

dir.create("out", showWarnings = FALSE)
write.csv(res, "out/specification-curve.csv", row.names = FALSE)

png("out/specification-curve.png", width = 980, height = 560)
par(mar = c(5, 17, 4, 2))
o <- order(res$pct_change)
bp <- barplot(res$pct_change[o], horiz = TRUE, names.arg = res$spec[o], las = 1,
        col = ifelse(res$pct_change[o] < 0, "grey25", "grey75"), xlim = c(-70, 20),
        xlab = "change in fog-day rate, first window to last (%)",
        main = "Twelve ways of measuring the same decline")
abline(v = 0); abline(v = -33.3, lty = 2)
text(res$pct_change[o] + ifelse(res$pct_change[o] < 0, -3, 3), bp,
     sprintf("%+.1f", res$pct_change[o]), cex = 0.85)
dev.off()

cat(sprintf("%d of %d specifications give a decline; median %+.1f%%\n",
            sum(res$pct_change < 0), nrow(res), median(res$pct_change)))
print(res)
