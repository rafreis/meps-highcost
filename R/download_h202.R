# =============================================================================
# meps-highcost / R/download_h202.R
# Downloads the Panel 21 two-year longitudinal file (HC-202, 2016-2017) from
# AHRQ MEPS into data/raw/HC-202/, writes a checksum manifest, and verifies
# against R/config.R's PANEL_MAP (must be HC-202).
# Deterministic / re-runnable: skips download if file + checksum already
# match; always re-verifies the checksum file.
# =============================================================================

suppressPackageStartupMessages({
  library(tools)   # md5sum
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

# Resolve project root: prefer current working directory (scripts are run
# with cwd = project root); fall back to script's own directory via
# commandArgs when invoked with Rscript from elsewhere.
.resolve_root <- function() {
  if (file.exists(file.path(".", "R", "config.R"))) return(normalizePath(".", mustWork = FALSE))
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grepl("^--file=", args)])
  if (length(file_arg) == 1 && nzchar(file_arg)) {
    return(normalizePath(file.path(dirname(file_arg), ".."), mustWork = FALSE))
  }
  normalizePath(".", mustWork = FALSE)
}
PROJECT_ROOT <- .resolve_root()

HC_ID     <- "HC-202"
RAW_DIR   <- file.path(PROJECT_ROOT, "data", "raw", HC_ID)
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)

# AHRQ MEPS HC-202 (Panel 21 Longitudinal, 2016-2017), Stata transport (.dta)
# Canonical AHRQ download page: https://meps.ahrq.gov/mepsweb/data_stats/download_data_files_detail.jsp?cboPufNumber=HC-202
FILE_URL  <- "https://meps.ahrq.gov/mepsweb/data_files/pufs/h202/h202dta.zip"
ZIP_PATH  <- file.path(RAW_DIR, "h202dta.zip")
DTA_NAME  <- "h202.dta"
DTA_PATH  <- file.path(RAW_DIR, DTA_NAME)
CHECKSUM_PATH <- file.path(RAW_DIR, "CHECKSUMS.txt")

download_ok <- FALSE
err_msg <- NA_character_

if (!file.exists(DTA_PATH)) {
  message("Downloading ", HC_ID, " from AHRQ: ", FILE_URL)
  tryCatch({
    utils::download.file(FILE_URL, destfile = ZIP_PATH, mode = "wb", quiet = FALSE)
    utils::unzip(ZIP_PATH, exdir = RAW_DIR, overwrite = TRUE)
    download_ok <- TRUE
  }, error = function(e) {
    err_msg <<- conditionMessage(e)
    message("Primary URL failed: ", err_msg)
  })
} else {
  message(DTA_NAME, " already present in ", RAW_DIR, " - skipping download.")
  download_ok <- TRUE
}

# Locate the .dta after extraction (AHRQ zip sometimes nests or cases differ)
if (!file.exists(DTA_PATH)) {
  candidates <- list.files(RAW_DIR, pattern = "(?i)^h202.*\\.dta$", full.names = TRUE, recursive = TRUE)
  if (length(candidates) >= 1) {
    file.copy(candidates[1], DTA_PATH, overwrite = TRUE)
  }
}

if (!file.exists(DTA_PATH)) {
  stop(
    "FAILED to obtain ", DTA_PATH, ". Download error: ", err_msg,
    ". Manually place h202.dta (or h202.ssp) in ", RAW_DIR,
    " from https://meps.ahrq.gov/mepsweb/data_stats/download_data_files_detail.jsp?cboPufNumber=HC-202"
  )
}

# -----------------------------------------------------------------------------
# Checksum manifest (data contract: reproducibility - checksum raw downloads)
# -----------------------------------------------------------------------------
md5 <- tools::md5sum(DTA_PATH)
size_bytes <- file.info(DTA_PATH)$size

manifest <- data.frame(
  file      = basename(DTA_PATH),
  hc_id     = HC_ID,
  md5       = unname(md5),
  size_bytes = size_bytes,
  source_url = FILE_URL,
  downloaded_at = as.character(Sys.time()),
  stringsAsFactors = FALSE
)

write.table(
  manifest, CHECKSUM_PATH, sep = "\t", row.names = FALSE, quote = FALSE
)

message("Checksum manifest written: ", CHECKSUM_PATH)
message("MD5(", DTA_NAME, ") = ", unname(md5), " | size = ", size_bytes, " bytes")

# Sanity: forbid HC-236 ever landing in this directory tree
forbidden_hits <- list.files(file.path(PROJECT_ROOT, "data", "raw"), pattern = "(?i)h236", recursive = TRUE)
if (length(forbidden_hits) > 0) {
  stop("FORBIDDEN FILE DETECTED (HC-236, 4-yr file): ", paste(forbidden_hits, collapse = ", "))
}

message(HC_ID, " ready at: ", DTA_PATH)
