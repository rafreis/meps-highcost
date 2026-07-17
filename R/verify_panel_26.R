suppressPackageStartupMessages(library(dplyr))
df <- readRDS(file.path("data", "derived", "panel_26.rds"))

cat("dim:", nrow(df), "x", ncol(df), "\n")
cat("panel unique:", paste(unique(df$panel), collapse=","), "\n")
cat("year1/year2 unique:", paste(unique(df$year1), collapse=","), "/", paste(unique(df$year2), collapse=","), "\n")
cat("dupersid duplicated?", any(duplicated(df$dupersid)), "\n")
cat("longwt range:", paste(range(df$longwt), collapse=" - "), "\n")
cat("varstr n distinct:", length(unique(df$varstr)), "\n")
cat("varpsu n distinct:", length(unique(df$varpsu)), "\n")
cat("totexp_y1 NA count:", sum(is.na(df$totexp_y1)), " totexp_y2 NA count:", sum(is.na(df$totexp_y2)), "\n")
cat("totexp_y1 range:", paste(round(range(df$totexp_y1)), collapse=" - "), "\n")
cat("totexp_y2 range:", paste(round(range(df$totexp_y2)), collapse=" - "), "\n")

canonical <- c("dupersid","panel","year1","year2","totexp_y1","totexp_y2",
               "top_decile_y2","longwt","varstr","varpsu")
cat("all canonical present:", all(canonical %in% names(df)), "\n")

feat_cols <- grep("^f_", names(df), value = TRUE)
cat("n f_* cols:", length(feat_cols), "\n")
leaky <- grep("_y2$", names(df), ignore.case = TRUE, value = TRUE)
leaky <- setdiff(leaky, "top_decile_y2")
cat("leaky non-f_ *_y2 cols besides totexp_y2 (contract-approved) / top_decile_y2:\n")
print(setdiff(leaky, "totexp_y2"))
leaky_feat <- grep("_y2$", feat_cols, ignore.case = TRUE, value = TRUE)
cat("leaky f_* cols (must be empty):", paste(leaky_feat, collapse=","), "\n")

cat("\nfeature col names:\n")
print(feat_cols)

cat("\nstr of first few cols:\n")
str(df[1:12])
