
export shock_gtap

import GlobalTradeAnalysisProjectModelV7 as GTAP
using HeaderArrayFile
using NamedArrays

"""
    shock_gtap(model::GTAP.model_container_struct, labour_scaling::Float64)

Apply a labour endowment shock to a GTAP economic model and compute the resulting economic outcomes.

This function scales labour endowments (both skilled and unskilled) across all sectors and regions by a specified factor, then runs the GTAP model to compute the equilibrium response. The shock is applied uniformly across labour types and sectors while allowing the model's CES rule to re-distribute labour across sectors.

# Arguments
- `model::GTAP.model_container_struct`: A GTAP model container with initialized data, sets, and parameters
- `labour_scaling::Float64`: Multiplier applied to labour endowments (e.g., 0.5 for a 50% reduction)

# Returns
A named tuple `(y_by_q, ev_by_q)` containing:
- `y_by_q`: NamedArray of GDP/income by region
- `ev_by_q`: NamedArray of equivalent variation (welfare change) by region relative to baseline
"""
function shock_gtap(model::GTAP.model_container_struct,
        labour_scaling::Float64
)
    # TODO: check inputs?

    # Save the calibrated data
    calibrated_data = deepcopy(model.data)

    regions = model.sets["reg"]
    labour_name = ["skilled labor", "unskilled labor"]

    # make a deep copy as calibrated data is modified in place
    # NOTE: example data has NaNs - unclear whether this is expected or
    # these should be replaced with zeros
    # NOTE: "qes" is endowment supply per sector and region; "qe" is the
    # regional aggregate from which the GTAP model's CES rule would
    # re-distribute labour across sectors (inappropriate for a pandemic shock)
    base_qes = deepcopy(calibrated_data["qes"])

    # prepare storage for results
    # NOTE: no real reason to use NamedArray other than user convenience IMO
    y_by_q = NamedArray(zeros(length(regions), 1), (regions, [1]))
    ev_by_q = NamedArray(zeros(length(regions), 1), (regions, [1]))

    # NOTE: must re-use initial value as model.data is modified in place
    # NOTE: shock all regions equally; may need region-specific shocks later
    model.data["qe"][labour_name, :] .= base_qes[labour_name, :, :] .*
                                        labour_scaling

    # get new equilibrium
    run_model!(model)

    # save outputs
    y_by_q[:, 1] .= model.data["y"]  # GDP/income
    ev_by_q[:, 1] .= calculate_expenditure(
        sets = model.sets,
        data0 = calibrated_data,
        data1 = model.data,
        parameters = model.parameters
    ) .- calibrated_data["y"]

    # examine gdp/income and expenditure
    # NOTE: I don't understand the specifics of the internal calculations
    # or the correct interpretation

    return (y_by_q = y_by_q, ev_by_q = ev_by_q)
end
