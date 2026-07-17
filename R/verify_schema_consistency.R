source("R/config.R")
panels <- c(21,22,23,26,27)
for (p in panels) {
  f <- file.path(DIR_DERIVED, paste0("panel_", p, ".rds"))
  if (!file.exists(f)) { cat(p, ": MISSING\n"); next }
  d <- readRDS(f)
  cat("panel", p, ": rows=", nrow(d), " cols=", ncol(d),
      " has_canon=", all(setdiff(CANONICAL_COLUMNS, character(0)) %in% names(d)), "\n")
}
