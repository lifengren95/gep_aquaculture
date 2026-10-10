# Code Repository for the GEP - Aquaculture Project

This repository contains the input data, R code, and country-level results used to estimate commercial aquaculture Gross Ecosystem Product (GEP) in 2019 U.S. dollars.

## Repository contents

| Folder | File | Description |
| --- | --- | --- |
| `data/` | [aquaculture_gtap_fsh_shares_by_region.csv](data/aquaculture_gtap_fsh_shares_by_region.csv) | Natural-resource shares for 50 GTAP regions, expressed relative to value added and gross output, together with the value-added-to-gross-output ratio. |
| `data/` | [aquaculture_details.xlsx](data/aquaculture_details.xlsx) | Country-level aquaculture data, including the `aquaculture_value_2019usd` column used in the calculation. |
| `code/` | [gep_aquaculture_natresfromgtap_2026oct09.R](code/gep_aquaculture_natresfromgtap_2026oct09.R) | Maps regional gross-output shares to r250 countries, joins aquaculture values, and calculates GEP. |
| `results/` | [r250_gtap_natresshare_grossoutput.csv](results/r250_gtap_natresshare_grossoutput.csv) | Natural-resource share of gross output assigned to each country. |
| `results/` | [aquaculture_gep_2026oct09.csv](results/aquaculture_gep_2026oct09.csv) | Country identifiers, aquaculture production values, natural-resource shares, and calculated aquaculture GEP. |

## Calculation

The natural-resource share of gross output is the GTAP `EVFP` payment to the `NatRes` endowment for the `fsh` activity divided by that activity's gross output, calculated by summing `MAKS` over commodities. Each country's share is inherited from its GTAP r50 region through the r250–r50 correspondence.

```r
aquaculture_gep <- aquaculture_value_2019usd *
                  natural_resource_share_of_gross_output
```

The calculation uses the gross-output share because aquaculture production value represents revenue. GTAP's `fsh` activity combines capture fisheries and aquaculture, so its natural-resource share is used as a proxy for aquaculture. All 250 country records are retained; missing production values or shares produce missing GEP values, written as blank CSV fields.

## Running the code

Install the required R packages:

```r
install.packages(c("sf", "data.table", "readxl"))
```

The script also requires `ee_r250_correspondence.gpkg`, layer `ee_r250_correspondence`, which is excluded from this repository. It uses the `iso3_r250_label`, `iso3_r250_id`, `iso3_r250_name`, and `gtapv7_r50_label` fields.

Before running, update the script's input and output paths to match your local setup, including the external GeoPackage. The current script retains the original project paths. Run the entire script in R or RStudio to generate both result CSVs.
