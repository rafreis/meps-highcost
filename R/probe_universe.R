# Quick probe: dump the Y1-intersection universe + clinically-relevant round-based
# candidate names common to all 5 panels, to design exclusion/allowlist rules.
suppressPackageStartupMessages(library(haven))
RAW <- c("data/raw/HC-202/h202.dta","data/raw/HC-210/h210.dta","data/raw/HC-217/h217.dta",
         "data/raw/h244/h244.dta","data/raw/HC-252/h252.dta")
nm <- lapply(RAW, function(p) toupper(names(haven::read_dta(p, n_max = 0))))
common <- Reduce(intersect, nm)
y1 <- Reduce(intersect, lapply(nm, function(x) x[grepl("[A-Z]Y1X?$", x)]))
dir.create("outputs", showWarnings = FALSE)
writeLines(sort(y1), "outputs/universe_y1_names.txt")

# clinically-relevant round-based / non-Y1 constructs common to all 5 panels
pat <- "^(RTHLTH|MNHLTH|ADGENH|ADDAYA|ACTLIM|WRKLIM|SOCLIM|COGLIM|HSELIM|SELFLIM|ADL|IADL|AIDHLP|WLKLIM|DDNWRK|PRIOLIST|DIABDX|PROBLM|ADHD|ADHDADD|LANG|USBORN|USC|HAVEUS|RATEHLT)"
round_cand <- sort(common[grepl(pat, common)])
writeLines(round_cand, "outputs/roundbased_candidates.txt")

cat("Y1 intersection:", length(y1), "\n")
cat("common (all-5) names:", length(common), "\n")
cat("round-based clinical candidates (all 5):", length(round_cand), "\n\n")
cat("--- ROUND-BASED CANDIDATES ---\n"); cat(round_cand, sep = "\n")
