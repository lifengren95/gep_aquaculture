# Map GTAP r50 natural-resource shares to r250 countries and calculate
# aquaculture GEP in 2019 USD. Date: 2026-10-09.
# Run this entire script in R/RStudio; paths do not depend on getwd().
# Install these packages once, if needed:
# install.packages(c("sf", "data.table", "readxl"))

required_packages <- c("sf", "data.table", "readxl")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Install the required packages first: install.packages(c(",
       paste(sprintf('"%s"', missing_packages), collapse = ", "), "))",
       call. = FALSE)
}
suppressPackageStartupMessages({
  library(sf)
  library(data.table)
})

# Input and output paths ---------------------------------------------------
project_dir <- "F:/Dropbox/400_research/430_projects/432_UMN/443_gep"
data_dir <- file.path(project_dir, "gep_fisheries/intermediate/gep_fish/2026")
shares_file <- file.path(data_dir, "aquaculture_gtap_fsh_shares_by_region.csv")
details_file <- file.path(data_dir, "aquaculture_details.xlsx")
correspondence_file <- file.path(project_dir, "ee_r250_correspondence.gpkg")
country_shares_file <- file.path(data_dir, "r250_gtap_natresshare_grossoutput.csv")
final_file <- file.path(data_dir, "aquaculture_gep_2026oct09.csv")

input_files <- c(shares_file, details_file, correspondence_file)
if (any(!file.exists(input_files))) {
  stop("Missing input file(s):\n",
       paste(input_files[!file.exists(input_files)], collapse = "\n"),
       call. = FALSE)
}

# Validation helpers ------------------------------------------------------
require_columns <- function(dt, columns, source_name) {
  missing <- setdiff(columns, names(dt))
  if (length(missing)) {
    stop(source_name, " is missing column(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
}

normalize_label <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x[is.na(x) | x == ""] <- NA_character_
  x
}

require_unique_key <- function(dt, column, source_name) {
  x <- dt[[column]]
  if (anyNA(x)) {
    stop(source_name, " contains missing ", column, " keys.", call. = FALSE)
  }
  if (anyDuplicated(x)) {
    stop(source_name, " contains duplicate ", column, " keys: ",
         paste(unique(x[duplicated(x)]), collapse = ", "), call. = FALSE)
  }
}

# Preserve real zeros and NA; reject unexpected text rather than treating it
# as missing data. Both source measures are numeric, with no unit conversion.
as_numeric_checked <- function(x, column) {
  text <- trimws(as.character(x))
  text[is.na(x) | text %in% c("", "NA")] <- NA_character_
  value <- suppressWarnings(as.numeric(text))
  if (any(!is.na(text) & (is.na(value) | !is.finite(value)))) {
    stop("Invalid numeric value in ", column, ".", call. = FALSE)
  }
  value
}

# 1. Read regional shares and the r250-to-r50 correspondence ----------------
regional_shares <- fread(shares_file, na.strings = c("", "NA"))
require_columns(regional_shares,
                c("gtap_region_label", "natural_resource_share_of_gross_output"),
                "Regional shares CSV")
regional_shares <- regional_shares[, .(
  gtapv7_r50_label = normalize_label(gtap_region_label),
  natural_resource_share_of_gross_output = as_numeric_checked(
    natural_resource_share_of_gross_output,
    "natural_resource_share_of_gross_output"
  )
)]
require_unique_key(regional_shares, "gtapv7_r50_label", "Regional shares CSV")

correspondence_sf <- st_read(
  correspondence_file, layer = "ee_r250_correspondence", quiet = TRUE
)
country_mapping <- as.data.table(st_drop_geometry(correspondence_sf))
require_columns(country_mapping,
                c("iso3_r250_label", "iso3_r250_id", "iso3_r250_name",
                  "gtapv7_r50_label"), "Correspondence GeoPackage")
country_mapping <- country_mapping[, .(
  iso3_r250_label = normalize_label(iso3_r250_label),
  iso3_r250_id,
  iso3_r250_name,
  gtapv7_r50_label = normalize_label(gtapv7_r50_label)
)]
require_unique_key(country_mapping, "iso3_r250_label", "Correspondence GeoPackage")

# A left join retains every r250 country. A missing regional match stays NA.
country_with_shares <- merge(
  country_mapping, regional_shares,
  by = "gtapv7_r50_label", all.x = TRUE, sort = FALSE
)
unmatched_regions <- setdiff(
  unique(na.omit(country_mapping$gtapv7_r50_label)),
  regional_shares$gtapv7_r50_label
)
if (length(unmatched_regions)) {
  warning("No share found for GTAP region(s): ",
          paste(unmatched_regions, collapse = ", "), call. = FALSE)
}
country_shares <- country_with_shares[, .(
  iso3_r250_label, natural_resource_share_of_gross_output
)]

# 2. Read the Excel aquaculture values -------------------------------------
# Sheet1 was inspected: it contains one row per r250 country, with the
# aquaculture_value_2019usd column already expressed in USD (not USD thousands).
aquaculture_details <- as.data.table(readxl::read_excel(
  details_file, sheet = "Sheet1", na = c("", "NA")
))
require_columns(aquaculture_details,
                c("iso3_r250_label", "aquaculture_value_2019usd"),
                "Aquaculture Excel file")
aquaculture_values <- aquaculture_details[, .(
  iso3_r250_label = normalize_label(iso3_r250_label),
  aquaculture_value_2019usd = as_numeric_checked(
    aquaculture_value_2019usd, "aquaculture_value_2019usd"
  )
)]
require_unique_key(aquaculture_values, "iso3_r250_label", "Aquaculture Excel file")

unmatched_countries <- setdiff(aquaculture_values$iso3_r250_label,
                              country_mapping$iso3_r250_label)
if (length(unmatched_countries)) {
  warning("Excel country key(s) absent from r250 correspondence: ",
          paste(unmatched_countries, collapse = ", "), call. = FALSE)
}

# 3. Join country shares, country metadata, and aquaculture values ----------
# Use the country_shares table that is saved to the intermediate CSV below.
result <- merge(
  country_mapping[, .(iso3_r250_label, iso3_r250_id, iso3_r250_name)],
  country_shares, by = "iso3_r250_label", all.x = TRUE, sort = FALSE
)
result <- merge(result, aquaculture_values,
                by = "iso3_r250_label", all.x = TRUE, sort = FALSE)

# In R, NA multiplied by any value (including zero) remains NA.
result[, aquaculture_gep :=
         aquaculture_value_2019usd * natural_resource_share_of_gross_output]
setcolorder(result, c(
  "iso3_r250_label", "iso3_r250_id", "iso3_r250_name",
  "aquaculture_value_2019usd", "natural_resource_share_of_gross_output",
  "aquaculture_gep"
))
setorder(result, iso3_r250_id)
setorder(country_shares, iso3_r250_label)
stopifnot(nrow(result) == nrow(country_mapping),
          !anyDuplicated(result$iso3_r250_label))

# 4. Save CSVs after the inputs and joins pass validation -------------------
# Existing files at these exact output paths are replaced on subsequent runs.
# na = "" writes R missing values as empty CSV fields, while retaining zeros.
fwrite(country_shares, country_shares_file, na = "")
fwrite(result, final_file, na = "")

message("Saved country shares: ", country_shares_file)
message("Saved aquaculture GEP: ", final_file)
message("Countries: ", nrow(result),
        "; missing aquaculture values: ", sum(is.na(result$aquaculture_value_2019usd)),
        "; missing shares: ", sum(is.na(result$natural_resource_share_of_gross_output)),
        "; missing GEP values: ", sum(is.na(result$aquaculture_gep)))
