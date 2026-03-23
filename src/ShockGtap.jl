export shock_gtap, ParameterShock

import GlobalTradeAnalysisProjectModelV7 as GTAP
using HeaderArrayFile
using NamedArrays

"""
    _apply_shocks!(data, base_data, shocks::Vector{ParameterShock})

Internal helper that applies a vector of parameter shocks to model data.

Mutates `data` in place, scaling values from `base_data` according to each
shock's scale factor.

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

            # only 2 and 3 dim arrays are expected for now
            # consider using EllipsisNotation.jl
            if ndims(base) == 3
                data[shock.parameter][idx, :, :] .= base[idx, :, :] .* shock.scale
            else
                data[shock.parameter][idx, :] .= base[idx, :] .* shock.scale
            end
        end
    end
end

"""
    shock_gtap(model::GTAP.model_container_struct, shocks::Vector{ParameterShock})

Apply parameter shocks to a GTAP economic model and compute the resulting
economic outcomes.

This function applies a vector of parameter shocks to the model data and runs
the GTAP model to compute the equilibrium response. Each shock scales a
specified parameter by a scale factor.

# Arguments
- `model::GTAP.model_container_struct`: A GTAP model container with initialized
    data, sets, and parameters
- `shocks::Vector{ParameterShock}`: Vector of parameter shocks to apply

# Returns
A named tuple `(y, ev, delta_gdp)` containing:
- `y`: NamedArray of GDP/income by region
- `ev`: NamedArray of equivalent variation (welfare change) by region relative
    to baseline
- `delta_gdp`: NamedArray of change in GDP between original calibrated model and
    new equilibrium.

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
    # make a copy of the model data; this will be modified in place later
    mod_data = model.data
    mod_copy = deepcopy(model)

    regions = mod_copy.sets["reg"]

    # prepare storage for results
    # NOTE: no real reason to use NamedArray other than user convenience IMO
    y = NamedArray(zeros(length(regions), 1), (regions, [1]))
    ev = NamedArray(zeros(length(regions), 1), (regions, [1]))

    # Apply all shocks to mod_copy data
    _apply_shocks!(mod_copy.data, mod_data, shocks)

    # get new equilibrium - operates on mod copy
    GTAP.run_model!(mod_copy)

    # save outputs; raw 'y', change in GDP, 'ev'
    y .= mod_copy.data["y"]  # GDP/income

    # compare initial gdp with new equilibrium
    qgdp1 = GTAP.calculate_gdp(sets = mod_copy.sets, data0 = mod_data,
        data1 = mod_copy.data)
    qgdp0 = GTAP.calculate_gdp(sets = mod_copy.sets, data0 = mod_data,
        data1 = mod_data)
    delta_gdp = qgdp1 ./ qgdp0 .- 1.0

    # so-called equivalent variation
    ev .= GTAP.calculate_expenditure(
        sets = mod_copy.sets,
        data0 = mod_data,
        data1 = mod_copy.data,
        parameters = mod_copy.parameters
    ) .- mod_data["y"]

    return (y = y, ev = ev, delta_gdp = delta_gdp)
end
