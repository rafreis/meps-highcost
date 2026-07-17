source("R/config.R")
p27 <- readRDS(file.path(DIR_DERIVED, "panel_27.rds"))

cat("dims:", nrow(p27), "x", ncol(p27), "\n")
cat("has all canonical cols:", all(CANONICAL_COLUMNS[CANONICAL_COLUMNS != "top_decile_y2"] %in% names(p27)) &&
      "top_decile_y2" %in% names(p27), "\n")

# leakage check across full frame (should only flag totexp_y2 + top_decile_y2 pass)
y2_cols <- grep("_y2$", names(p27), ignore.case = TRUE, value = TRUE)
cat("all _y2 cols in frame:", paste(y2_cols, collapse=", "), "\n")
bad <- setdiff(y2_cols, "top_decile_y2")
bad <- bad[bad != "totexp_y2"]  # totexp_y2 is allowed as canonical target-SOURCE column, just not model-eligible
cat("unexpected _y2 columns beyond totexp_y2/top_decile_y2:", paste(bad, collapse=", "), "(should be empty)\n")

# model-eligible columns must never include totexp_y2
elig <- names(p27)[is_model_eligible(names(p27))]
cat("model-eligible cols include totexp_y2?", "totexp_y2" %in% elig, "(should be FALSE)\n")
assert_no_leakage(elig)
cat("assert_no_leakage(elig) passed\n")

# weighted base rate via survey design
des <- make_survey_design(p27)
rate <- survey::svymean(~top_decile_y2, des, na.rm = TRUE)
cat("weighted top_decile_y2 rate:", coef(rate), "\n")

cat("dupersid uniqueness:", length(unique(p27$dupersid)) == nrow(p27), "\n")
cat("panel value(s):", paste(unique(p27$panel), collapse=","), "\n")
cat("year1/year2:", paste(unique(p27$year1), collapse=","), "/", paste(unique(p27$year2), collapse=","), "\n")
cat("NA longwt/varstr/varpsu:", sum(is.na(p27$longwt)), sum(is.na(p27$varstr)), sum(is.na(p27$varpsu)), "\n")
cat("any negative longwt (should be 0, but 0-weight rows for attrited persons are valid):", sum(p27$longwt < 0, na.rm=TRUE), "\n")
cat("n with longwt==0:", sum(p27$longwt == 0, na.rm=TRUE), "\n")
