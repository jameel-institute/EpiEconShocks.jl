
module ModelInit

export initial_gtap_model

using ..Helpers

import GlobalTradeAnalysisProjectModelV7 as GTAP
using HeaderArrayFile
using NamedArrays

"""
    initial_gtap_model(datadir::String;
        roi::Union{String, Vector{String}} = ["gbr", "usa", "chn"])::GTAP.model_container_struct

Initialize and calibrate a GTAP (Global Trade Analysis Project) economic model.

This function orchestrates the complete setup workflow for a GTAP model: loading raw trade and
economic data from HAR files, aggregating regions/commodities/endowments according to regional
interest (roi), building the model structure, and running calibration to ensure consistency.

# Arguments
- `datadir::String`: Path to directory containing the three GTAP data files:
  - `gsdfset.har`: Set definitions (regions, commodities, endowments)
  - `gsdfdat.har`: Economic data (bilateral trade flows, domestic transactions, value added)
  - `gsdfpar.har`: Parameters (elasticities, behavioral coefficients)
- `roi::Union{String, Vector{String}}`: Regions of interest to preserve in aggregation.
  Defaults to ["gbr", "usa", "chn", "eur"]. All other regions are aggregated to
  "row" (rest of world).

# Returns
- `model_container_struct`: A calibrated GTAP model ready for scenario analysis.

# Workflow
1. Loads three HAR files and converts to NamedArray dictionaries
2. Creates aggregation maps for regions, commodities, and endowments (grouping non-roi into defaults)
3. Aggregates all data/parameters/sets using these maps via `aggregate_data()`
4. Generates model structure from aggregated data via `generate_initial_model()`
5. Prepares calibration equations and data via `generate_calibration_inputs()`
6. Runs model in-place to enforce consistency and calibration constraints
7. Returns the calibrated model container
"""
function initial_gtap_model(datadir::String;
        roi::Union{String, Vector{String}} = ["gbr", "usa", "chn", "eur"])::GTAP.model_container_struct

    # TODO: add checks on datadir and files therein

    ## load raw data from HAR files
    gsdsets = HeaderArrayFile.File(joinpath(datadir, "gsdfset.har"))
    sets = Dict(keys(gsdsets) .=> NamedArray.(values(gsdsets)))

    gsddat = HeaderArrayFile.File(joinpath(datadir, "gsdfdat.har"))
    data = Dict(keys(gsddat) .=> NamedArray.(values(gsddat)))

    gsdparams = HeaderArrayFile.File(joinpath(datadir, "gsdfpar.har"))
    parameters = Dict(keys(gsdparams) .=> NamedArray.(values(gsdparams)))

    ## get aggregation mappings for regions, commodities, and endowments
    regions_agg = NamedArray(deepcopy(sets["reg"]), sets["reg"])
    regions_agg = cluster_regions(regions_agg, roi)

    comm_agg = NamedArray(deepcopy(sets["comm"]), sets["comm"])
    comm_agg = cluster_commodities(comm_agg)

    endow_agg = NamedArray(deepcopy(sets["endw"]), sets["endw"])
    endow_agg = cluster_endowments(endow_agg)

    (; hData,
        hParameters,
        hSets) = GTAP.aggregate_data(
        hData = data, hParameters = parameters, hSets = sets,
        comMap = comm_agg, regMap = regions_agg, endMap = endow_agg);

    ## generate model structure from aggregated data
    mc = GTAP.generate_initial_model(
        hSets = hSets, hData = hData, hParameters = hParameters);

    ## prepare and apply calibration
    start_data = deepcopy(mc.data) # only really used to validate calibration

    (; fixed_calibration,
        data_calibration) = GTAP.generate_calibration_inputs(mc, start_data);

    mc.data = deepcopy(data_calibration)
    mc.fixed = deepcopy(fixed_calibration)

    # run initial model in place
    GTAP.run_model!(mc)

    return mc
end

end
