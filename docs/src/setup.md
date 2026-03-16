```@meta
CurrentModule = EpiEconShocks
```

This page shows the steps needed to set up a GTAP equilibrium model.

## Getting GTAP data from the GTAP database

The GTAP data is licensed for use, and can be acquired from [INSERT LINK HERE]().

**Note** the following conditions:

1. You will need the data provided as a FlexAgg package;

2. The data must have the following files in the ['Fujitsu' Header Array FORTRAN format](https://www.copsmodels.com/webhelp/rungtap/index.html?hc_lhfilefmt.htm) (extension `.har`): `"gsdfset.har"` (GTAP sets), `"gsdfpar.har"` (GTAP parameters), and `"gsdfdat.har"` (GTAP data).

**NOTE: NEED TO EXPLAIN THE FILE CONTENTS IN BRIEF HERE!!**

3. _GlobalTradeAnalysisProjectv7.jl_ runs version 7 of the GTAP model, and is compatible with version 11 of the GTAP database. The package may be compatible with older versions of the database as well, but it has not been checked for such compatibility at the present time.

## Aggregating GTAP data

The functions [`Helpers.cluster_regions`](@ref), [`Helpers.cluster_commodities`](@ref), and [`Helpers.cluster_endowments`](@ref) can help with preparing `NamedArrays` to be passed to `GlobalTradeAnalysisProjectv7.aggregate_data()` to aggregate the GTAP data based on modelling needs.

## Warnings

A non-exhaustive list of issues discovered while using _GlobalTradeAnalysisProjectv7.jl_ are laid out below, to serve as reference points for users of _EpiEconShocks.jl_ encountering the same issues.

1. Using the full GTAP dataset (even at the `FlexAgg` stage **WHAT IS A GOOD DESCRIPTOR FOR THIS DATA??**) to set up an initial model is prohibitively memory intensive.
    For example, it fails on a 32 GB RAM machine during local testing.
    Users are *strongly advised* to aggregate the data to the geographies of concern using the function `GlobalTradeAnalysisProjectv7.aggregate_data`.
    We suggest that an appropriate aggregation would be to the countries of interest, and their major trading partners; all other regions can be aggregated into a 'rest of world' category.
