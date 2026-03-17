export shock_gtap, ParameterShock

import GlobalTradeAnalysisProjectModelV7 as GTAP
using HeaderArrayFile
using NamedArrays

"""
    _apply_shocks!(data, base_data, shocks::Vector{ParameterShock})

Internal helper that applies a vector of parameter shocks to model data.

Mutates `data` in place, scaling values from `base_data` according to each shock's scale factor.

# Arguments
- `data`: The mutable model data dictionary to be modified
- `base_data`: The calibrated baseline data (used as reference for scaling)
- `shocks::Vector{ParameterShock}`: Vector of shocks to apply
"""
function _apply_shocks!(data, base_data, shocks::Vector{ParameterShock})
    for shock in shocks
        base = base_data[shock.parameter]
        if isnothing(shock.indices)
            # Apply to all rows
            data[shock.parameter] .= base .* shock.scale
        else
            # Normalize String to Vector{String} to preserve 2-D slice semantics
            idx = shock.indices isa String ? [shock.indices] : shock.indices
            data[shock.parameter][idx, :] .= base[idx, :] .* shock.scale
        end
    end
end

"""
    shock_gtap(model::GTAP.model_container_struct, shocks::Vector{ParameterShock})

Apply parameter shocks to a GTAP economic model and compute the resulting economic outcomes.

This function applies a vector of parameter shocks to the model data and runs the GTAP model to compute the equilibrium response. Each shock scales a specified parameter by a scale factor.

# Arguments
- `model::GTAP.model_container_struct`: A GTAP model container with initialized data, sets, and parameters
- `shocks::Vector{ParameterShock}`: Vector of parameter shocks to apply

# Returns
A named tuple `(y_by_q, ev_by_q)` containing:
- `y_by_q`: NamedArray of GDP/income by region
- `ev_by_q`: NamedArray of equivalent variation (welfare change) by region relative to baseline

# Example

```julia
# Apply a 50% reduction to skilled and unskilled labor
shocks = [ParameterShock("qe", ["skilled labor", "unskilled labor"], 0.5)]
result = shock_gtap(model, shocks)
```
"""
function shock_gtap(model::GTAP.model_container_struct,
        shocks::Vector{ParameterShock}
)
    # TODO: check inputs?

    # Save the calibrated data
    calibrated_data = deepcopy(model.data)

    regions = model.sets["reg"]

    # prepare storage for results
    # NOTE: no real reason to use NamedArray other than user convenience IMO
    y_by_q = NamedArray(zeros(length(regions), 1), (regions, [1]))
    ev_by_q = NamedArray(zeros(length(regions), 1), (regions, [1]))

    # Apply all shocks to model data
    _apply_shocks!(model.data, calibrated_data, shocks)

    # get new equilibrium
    GTAP.run_model!(model)

    # save outputs
    y_by_q .= model.data["y"]  # GDP/income
    ev_by_q .= GTAP.calculate_expenditure(
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
