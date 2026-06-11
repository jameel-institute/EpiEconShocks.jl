```@meta
CurrentModule = EpiEconShocks
```

# Getting GTAP data from the GTAP database

This page shows the steps needed to set up a calibrated Global Trade Analysis Project (GTAP) model, using a GTAP database.

The GTAP data is licensed for use, and can be acquired from [the GTAP website](https://www.gtap.agecon.purdue.edu/).
A user account is required to log in before data can be accessed.
There are multiple GTAP database versions.

**Note** the following conditions:

1. You will need the data provided as a FlexAgg package;

2. The data must have the following files in the ['Fujitsu' Header Array FORTRAN format](https://www.copsmodels.com/webhelp/rungtap/index.html?hc_lhfilefmt.htm) (extension `.har`): `"gsdfset.har"` (GTAP sets), `"gsdfpar.har"` (GTAP parameters), and `"gsdfdat.har"` (GTAP data).

3. _GlobalTradeAnalysisProjectv7.jl_ runs version 7 of the GTAP model, and is compatible with version 11 of the GTAP database. The package may be compatible with older versions of the database as well, but it has not been checked for such compatibility at the present time. Since _EpiEconShocks.jl_ relies on _GlobalTradeAnalysisProjectv7.jl_, it has also only been tested for version 11 of the GTAP database.

## Using inbuilt model initialisation

The `ModelInit` module in _EpiEconShocks.jl_ provides [`ModelInit.initial_gtap_model`](@ref) to help get a calibrated 'baseline' model against which models incorporating shocks can be compared.

The function simply needs to be pointed at the directory holding GTAP data, and to be provided with a string vector of regions of interest.
All other regions, and the EU countries are aggregated into a 'rest of world' and 'EU states' category, respectively.
This default behaviour is because the package is currently aimed at a U.K. context.

!!! info "Region aggregation"
    _EpiEconShocks.jl_ currently aggregates GTAP regions into the United Kingdom, some major global economies, EU states, and all other regions. Countries modelled separately are the USA, China, France, Germany, China, India, and Japan.

!!! info "Commodity aggregation"
    _EpiEconShocks.jl_ currently aggregates GTAP commodities based on the [International Standard Industrial Classification of All Economic Activities (ISIC) revision 4](https://ilostat.ilo.org/methods/concepts-and-definitions/classification-economic-activities/) into all primary sectors ("allprimary", ISIC AB), manufacturing ("manufac", ISIC C), utilities ("utilities", ISIC DE), construction ("constr", ISIC F), retail ("retail", ISIC F), transport ("transport", ISIC H), hospitality ("hosp", ISIC I), information and computing-related services ("ict_prof_serv", ISIC JKLMN), publishing and administration ("pubadm", ISIC OPQ, U), and arts, recreation and others ("arts_rec_other", ISIC RST).

!!! info "Endowments aggregation"
    _EpiEconShocks.jl_ currently aggregates endowments into "land", "skilled labour", "unskilled labour", "capital", and "other",

This function returns a `GlobalTradeAnalysisProjectv7.model_container_struct` object which can be passed to downstream functions.

## Manually aggregating GTAP data

To set up your own GTAP model with customised sector and region aggregation, the helper functions [`Helpers.cluster_regions`](@ref), [`Helpers.cluster_commodities`](@ref), and [`Helpers.cluster_endowments`](@ref) can help with preparing `NamedArrays` to be passed to `GlobalTradeAnalysisProjectv7.aggregate_data()` to aggregate the GTAP data.

## Warnings

A non-exhaustive list of issues discovered while using _GlobalTradeAnalysisProjectv7.jl_ are laid out below, to serve as reference points for users of _EpiEconShocks.jl_ encountering the same issues.

1. Using the full GTAP dataset (even at the `FlexAgg` stage) to set up an initial model is prohibitively memory intensive.
    For example, it fails on a 32 GB RAM machine during local testing.
    Users are *strongly advised* to aggregate the data to the geographies of concern using the function `GlobalTradeAnalysisProjectv7.aggregate_data`.
    We suggest that an appropriate aggregation would be to the countries of interest and their major trading partners; all other regions can be aggregated into a 'rest of world' category.
    Similarly, commodities and endowments should be aggregated to a sensible set.

Please contribute or report other issues encountered so these can be added here.
