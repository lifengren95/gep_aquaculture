# GEP – Aquaculture Project

This repository contains the data, R code, and results used to estimate commercial aquaculture Gross Ecosystem Product (GEP) in 2019 U.S. dollars.

- **data/** — Aquaculture production values and GTAP natural-resource shares.
- **code/** — R script that maps regional shares to countries and calculates aquaculture GEP.
- **results/** — Country-level natural-resource shares and aquaculture GEP estimates.

Aquaculture GEP is calculated by multiplying each country’s production value by its GTAP region’s natural-resource share of gross output. Missing values remain blank in the results.

The country-to-GTAP-region correspondence GeoPackage is required to run the script and is not included in this repository.
