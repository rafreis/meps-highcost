# Definitive DESIGN-BASED LASSO via svyVarSel::wlasso (Iparragirre & Lumley 2023),
# method = dCV (design-based cross-validation with replicate weights built from
# strata/cluster). Runs over the exported Rao-Scott candidate matrix.
# Reproduce locally: source this after install.packages("svyVarSel").
suppressPackageStartupMessages({ library(svyVarSel); library(jsonlite) })

d <- readRDS("outputs/train_lasso_input.rds")
cand <- grep("^f_", names(d), value = TRUE)

# wlasso -> glmnet does not accept NAs; median-impute candidate cols (train only)
impute_med <- function(x){ m <- median(x, na.rm = TRUE); x[is.na(x)] <- m; x }
d[cand] <- lapply(d[cand], impute_med)
d$top_decile_y2 <- as.integer(d$top_decile_y2)

set.seed(42)
fit <- wlasso(data = d, col.y = "top_decile_y2", col.x = cand,
              cluster = "varpsu", strata = "str_p", weights = "longwt",
              family = "binomial", method = "dCV", k = 10)

beta <- as.matrix(fit$model$min$beta)
sel  <- rownames(beta)[beta[,1] != 0]
sel  <- setdiff(sel, "(Intercept)")
coefs <- data.frame(feature = sel, coef = beta[sel, 1], row.names = NULL)
coefs <- coefs[order(-abs(coefs$coef)), ]

write.csv(coefs, "outputs/whitelist_wlasso.csv", row.names = FALSE)
report <- list(method = "svyVarSel::wlasso dCV k=10",
               n_candidates = length(cand),
               lambda_min = tryCatch(fit$lambda$min, error = function(e) NA),
               n_selected = length(sel),
               selected = coefs$feature)
writeLines(toJSON(report, auto_unbox = TRUE, pretty = TRUE, na = "null"),
           "outputs/wlasso_selected.json")
cat("\n--- wlasso (dCV) selected", length(sel), "features ---\n")
print(coefs, row.names = FALSE)
