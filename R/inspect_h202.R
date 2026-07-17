suppressPackageStartupMessages(library(haven))
PROJECT_ROOT <- normalizePath(".", mustWork = FALSE)
DTA_PATH <- file.path(PROJECT_ROOT, "data", "raw", "HC-202", "h202.dta")

# Read only variable metadata (haven can read just column names quickly via
# read_dta with n_max = 0, which still parses the full dictionary).
d0 <- haven::read_dta(DTA_PATH, n_max = 0)
nms <- names(d0)
cat("TOTAL VARS:", length(nms), "\n\n")

pattern_hits <- function(pat) grep(pat, nms, value = TRUE, ignore.case = TRUE)

cat("== ID ==\n"); print(pattern_hits("^DUPERSID$|^PANEL$"))
cat("\n== WEIGHT/DESIGN ==\n"); print(pattern_hits("LONGWT|VARSTR|VARPSU"))
cat("\n== TOTEXP ==\n"); print(pattern_hits("TOTEXP"))
cat("\n== YEAR MARKERS ==\n"); print(pattern_hits("^YEAR"))
cat("\n== AGE ==\n"); print(pattern_hits("^AGE"))
cat("\n== SEX ==\n"); print(pattern_hits("^SEX"))
cat("\n== RACE/ETHNICITY ==\n"); print(pattern_hits("RACE|HISP|RACETHX"))
cat("\n== REGION ==\n"); print(pattern_hits("^REGION"))
cat("\n== POVERTY/INCOME ==\n"); print(pattern_hits("POVCAT|POVLEV|TTLP|FAMINC"))
cat("\n== INSURANCE ==\n"); print(pattern_hits("INSCOV|INSURC"))
cat("\n== EMPLOYMENT ==\n"); print(pattern_hits("^EMPST"))
cat("\n== EDUCATION ==\n"); print(pattern_hits("EDUC"))
cat("\n== MARITAL ==\n"); print(pattern_hits("MARRY"))
cat("\n== HEALTH STATUS ==\n"); print(pattern_hits("RTHLTH|MNHLTH"))
cat("\n== BMI ==\n"); print(pattern_hits("^BMI"))
cat("\n== SMOKE ==\n"); print(pattern_hits("^ADSMOK|SMOKE"))
cat("\n== UTILIZATION COUNTS (OBV/OPT/IPT/ERT/RX etc) ==\n"); print(pattern_hits("^OBV|^OPT|^IPT|^ERT|^RX|^DV"))
cat("\n== CHRONIC CONDITIONS FLAGS ==\n"); print(pattern_hits("DIABDX|HIBPDX|CHDDX|ASTHDX|CANCERDX|ARTHDX|STRKDX|EMPHDX|CHOLDX"))
cat("\n== ACTIVITY/WORK/COGNITIVE LIMITATION ==\n"); print(pattern_hits("ACTLIM|WRKLIM|COGLIM"))
cat("\n== FAMILY SIZE ==\n"); print(pattern_hits("FAMSZE|FAMSZ"))
cat("\n== UNINSURED FLAG ==\n"); print(pattern_hits("UNINS"))
cat("\n== USUAL SOURCE OF CARE ==\n"); print(pattern_hits("HAVEUS"))
cat("\n== PERWT/SAQWT (forbidden weights, verify not confused) ==\n"); print(pattern_hits("PERWT|SAQWT"))

# Dump ALL names to a file for careful cross-referencing.
writeLines(nms, file.path(PROJECT_ROOT, "data", "raw", "HC-202", "VARNAMES_h202.txt"))
cat("\nFull variable list written to VARNAMES_h202.txt\n")
