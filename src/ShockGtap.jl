export shock_gtap, ParameterShock, compare_gtaps

import GlobalTradeAnalysisProjectModelV7 as GTAP
using HeaderArrayFile
using NamedArrays

"""
    _apply_shocks!(data, base_data, shocks::Vector{ParameterShock})

Internal helper that applies a vector of parameter shocks to model data.

Mutates `data` in place, scaling values from `base_data` according to each
shock's scale and region-specific factors.

# Arguments
- `data`: The mutable model data dictionary to be modified
- `base_data`: The calibrated baseline data (used as reference for scaling)
- `shocks::Vector{ParameterShock}`: Vector of shocks to apply (may include region-specific shocks)

# Details
Applies shocks in the following order:
1. Commodity/endowment-specific scaling (via indices and scale)
2. Region-specific scaling (via regions and region_scale, if provided)

For region-specific shocks, scaling is applied to the last dimension(s) of the
parameter array (assumed to be regions).
"""
function _apply_shocks!(data, base_data, shocks::Vector{ParameterShock})
    for shock in shocks
        base = base_data[shock.parameter]

        # First apply commodity/endowment-level shocks
        if isnothing(shock.indices)
            # Apply to all rows
            data[shock.parameter] .= base .* shock.scale
        else
            # Normalize String to Vector{String} to preserve 2-D slice semantics
            rows = shock.indices isa String ? [shock.indices] : shock.indices
            regions = isa(shock.scale, NamedArray) ? names(shock.scale, 2) :
                      1:(size(data[shock.parameter])[2])

            # only 2 and 3 dim arrays are expected for now,
            # TODO: MUST SCALE INCOMING AND OUTGOING IN TRADE
            # CHANNELS DIFFERENTLY!! UNCLEAR WHAT IS SCALED NOW?
            if ndims(base) == 3
                data[shock.parameter][rows, :, regions] .= base[rows, :, regions] .*
                                                           shock.scale
            else
                data[shock.parameter][rows, regions] .= base[rows, regions] .* shock.scale
            end
        end
    end
end

"""
    shock_gtap(model::GTAP.model_container_struct, shocks::Vector{ParameterShock})

Apply parameter shocks to a GTAP economic model and compute a new equilibrium.

This function applies a vector of parameter shocks to a deep copy of the input model,
runs the GTAP model to compute the new equilibrium response, and returns the modified
model. The original model is left unchanged.

# Arguments
- `model::GTAP.model_container_struct`: A GTAP model container with initialized
    data, sets, and parameters
- `shocks::Vector{ParameterShock}`: Vector of parameter shocks to apply. Each shock
    scales a specified parameter value by a given scale factor.

# Returns
`GTAP.model_container_struct`: A modified copy of the input model containing:
- Updated data arrays reflecting the applied shocks
- Solved equilibrium values for endogenous variables (e.g., model.data["y"] for income)
- Original sets and parameters

To extract economic outcomes from the result, use `compare_gtaps(original_model, result_model)`
to get GDP changes, equivalent variation, and other comparisons.

# Example

```julia
# Apply a 50% reduction to skilled and unskilled labor
shocks = [ParameterShock("qe", ["skilled labor", "unskilled labor"], 0.5)]
shocked_model = shock_gtap(model, shocks)

# Compare with original to get economic outcomes
outcomes = compare_gtaps(model, shocked_model)
```
"""
function shock_gtap(model::GTAP.model_container_struct,
        shocks::Vector{ParameterShock}
)::GTAP.model_container_struct
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

    return mod_copy
end

"""
    compare_gtaps(initial::GTAP.model_container_struct, current::GTAP.model_container_struct)

Compare baseline and shocked GTAP models to extract economic outcomes.

Computes changes in economic indicators between two model states by calculating:
1. Absolute income/GDP by region in the current (shocked) model
2. Equivalent variation (welfare change relative to baseline) by region
3. Proportional change in GDP by region between baseline and current equilibrium

# Arguments
- `initial::GTAP.model_container_struct`: Baseline model (typically the original or baseline equilibrium)
- `current::GTAP.model_container_struct`: Shocked or alternative model (typically the result of `shock_gtap`)

# Returns
A named tuple `(y, ev, delta_gdp)` containing:
- `y::NamedArray`: Absolute income/GDP by region in the current model
- `ev::NamedArray`: Equivalent variation (change in expenditure function) by region, measuring
    welfare change relative to the initial equilibrium
- `delta_gdp::NamedArray`: Proportional change in GDP by region, calculated as
    `(GDP_current / GDP_initial) - 1.0`

# Details
- `delta_gdp` is a proportional measure and can have negative values.
- All results are indexed by region names from the model's region set.

# Example

```julia
# Create a shocked model
labour_shock = ParameterShock("qe", ["skilled labour", "unskilled labour"], 0.9)
shocked_model = shock_gtap(baseline_model, [labour_shock])

# Compare to extract outcomes
outcomes = compare_gtaps(baseline_model, shocked_model)
println("GDP change by region: \", outcomes.delta_gdp)
println("Welfare change by region: \", outcomes.ev)
```
"""
function compare_gtaps(initial::GTAP.model_container_struct, current::GTAP.model_container_struct)
    regions = current.sets["reg"]

    # Prepare storage for results
    y = NamedArray(zeros(length(regions), 1), (regions, [1]))
    ev = NamedArray(zeros(length(regions), 1), (regions, [1]))

    # Save absolute income/GDP in current model
    y .= current.data["y"]  # GDP/income

    # Compare initial gdp with new equilibrium
    qgdp1 = GTAP.calculate_gdp(sets = current.sets, data0 = initial.data,
        data1 = current.data)
    qgdp0 = GTAP.calculate_gdp(sets = current.sets, data0 = initial.data,
        data1 = initial.data)
    delta_gdp = qgdp1 ./ qgdp0 .- 1.0

    # So-called equivalent variation (welfare change)
    ev .= GTAP.calculate_expenditure(
        sets = current.sets,
        data0 = initial.data,
        data1 = current.data,
        parameters = current.parameters
    ) .- initial.data["y"]

    return (y = y, ev = ev, delta_gdp = delta_gdp)
end
