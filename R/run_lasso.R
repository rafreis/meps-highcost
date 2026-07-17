# Design-aware LASSO parsimony step over the exported Rao-Scott candidate set.
# Weighted (LONGWT) LASSO with CLUSTER-RESPECTING CV folds (whole PSUs -> folds).
# Reports lambda.1se (parsimonious, recommended) and lambda.min selections.
# NOTE: pragmatic design-aware selector; confirm with wlasso (dCV) locally.
suppressPackageStartupMessages({ library(glmnet); library(jsonlite) })

d <- readRDS("outputs/train_lasso_input.rds")
cand <- grep("^f_", names(d), value = TRUE)
FORCE <- intersect(c("f_totexp","f_totslf","f_age","f_sex","f_racev1x","f_racethx",
                     "f_hispanx","f_povcat","f_povlev","f_ttlp","f_faminc",
                     "f_inscov","f_unins"), cand)

impute_med <- function(x){ m <- median(x, na.rm=TRUE); x[is.na(x)] <- m; x }
X <- as.matrix(as.data.frame(lapply(d[cand], impute_med)))
y <- d$top_decile_y2; wt <- d$longwt

clus <- factor(paste(d$str_p, d$varpsu)); uc <- levels(clus)
set.seed(42); fmap <- setNames(sample(rep(1:10, length.out = length(uc))), uc)
foldid <- as.integer(fmap[as.character(clus)])

cvf <- cv.glmnet(X, y, family="binomial", weights=wt, foldid=foldid, alpha=1,
                 penalty.factor = ifelse(cand %in% FORCE, 0, 1))  # never penalize anchors

get_sel <- function(s){ co <- as.matrix(coef(cvf, s=s))
  data.frame(feature=rownames(co), coef=co[,1], row.names=NULL) |>
    subset(feature != "(Intercept)" & coef != 0) }
sel_1se <- get_sel("lambda.1se"); sel_min <- get_sel("lambda.min")
sel_1se <- sel_1se[order(-abs(sel_1se$coef)), ]
sel_min <- sel_min[order(-abs(sel_min$coef)), ]

write.csv(sel_1se, "outputs/whitelist_final_1se.csv", row.names=FALSE)
write.csv(sel_min, "outputs/whitelist_final_min.csv", row.names=FALSE)
report <- list(
  n_candidates = length(cand),
  lambda_1se = cvf$lambda.1se, lambda_min = cvf$lambda.min,
  n_selected_1se = nrow(sel_1se), n_selected_min = nrow(sel_min),
  forced_anchors = FORCE,
  selected_1se = sel_1se$feature,
  selected_min = sel_min$feature)
writeLines(toJSON(report, auto_unbox=TRUE, pretty=TRUE), "outputs/lasso_selected.json")
cat("\n--- LASSO (lambda.1se, recommended) selected", nrow(sel_1se), "features ---\n")
print(sel_1se, row.names=FALSE)
cat("\n--- lambda.min selected", nrow(sel_min), "features ---\n")
cat(sel_min$feature, sep=", ")
cat("\n")
