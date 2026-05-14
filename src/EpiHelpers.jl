
module EpiHelpers

using DataFrames

export calc_labour_avail, calc_consumption_avail, integrate_shock

validate_scaling = function (scaling_dict::Dict, n_sectors::Real)
    for (key, val) in scaling_dict
        if !isa(val, Vector{Float64})
            throw(
                ArgumentError(
                "Expected scaling for $key to be a Float64 vector"
            )
            )
        end

        len_scaling = length(val)
        if len_scaling != n_sectors
            throw(ArgumentError(
                "Expected scaling for $key to be of length $n_sectors, got $len_scaling"
            ))
        end
    end

    return scaling_dict
end

default_labour_scaling = function (n_sectors::Real = 45)
    return Dict(
        "infect_symp" => repeat([1.0], n_sectors),
        "infect_asymp" => repeat([0.5], n_sectors),
        "hospitalised_recov" => repeat([1.0], n_sectors),
        "hospitalised_death" => repeat([1.0], n_sectors),
        "dead" => repeat([1.0], n_sectors)
    )
end

"""
    calc_labour_avail(epi_data::DataFrame, scaling::Dict, N_work::Real) -> Vector{Float64}

Calculate daily labour availability from epidemiological compartment data.

Computes the fraction of the workforce still available at each time point as
`1 − weighted_absence / N_work`, where the weighted absence is the row-wise sum of
each compartment column multiplied by its scalar weight from `scaling`.

For sector-stratified data with per-sector WFH fractions and furlough rates, use
`calc_avail_labour` instead.

# Arguments
- `epi_data::DataFrame`: Epidemiological time series; rows are time steps, columns are
  disease compartments. No sector column is expected.
- `scaling::Dict`: Maps compartment column names (`Symbol` or `String`) to their absence
  weights (all values must be scalar `Real`). For example, mildly symptomatic workers at
  36% absence: `Dict("mild" => 0.36, "severe" => 1.0)`.
- `N_work::Real`: Total workforce size used for normalisation.

# Returns
`Vector{Float64}`: Labour availability at each time step, typically in `[0.0, 1.0]`.

# Example
```julia
df = DataFrame(
    mild = [100, 150, 200], severe = [10, 15, 20],
    hosp = [5, 7, 10],      dead   = [1,  2,  3]
)
scaling = Dict("mild" => 0.36, "severe" => 1.0, "hosp" => 1.0, "dead" => 1.0)
avail = calc_labour_avail(df, scaling, 10_000.0)
# Row 1: absence = 36 + 10 + 5 + 1 = 52 → 1 − 52/10000 = 0.9948
```
"""
calc_labour_avail = function (df::DataFrame,
        comp_affected::Union{String, Vector{String}} =
        ["infect_symp", "infect_asymp", "dead", "hospitalised_recov",
            "hospitalised_death"],
        scaling_affected::Dict = default_labour_scaling(),
        scaling_wfh::Union{Float64, Vector{Float64}} = 0.5,
        scaling_care::Union{Float64, Vector{Float64}} = 1.0,
        scaling_furl::Union{Float64, Vector{Float64}} = 1.0,
        phi_eco::Float64 = 1.0,
        n_workers::Union{Float64, Vector{Float64}} = 1.0;
        col_sector = "econ_sector",
        combine_sectors::Bool = false
)
    max_time = maximum(df.time) # expect time col
    n_sectors = length(unique(df[:, col_sector]))

    scaling_affected = validate_scaling(scaling_affected, n_sectors)

    # bit of a hash; should always have correct number of workers
    # do method for daedalus_country class
    n_workers = n_sectors > 1 ? repeat([n_workers], n_sectors) : n_workers

    comp_affected = isa(comp_affected, Vector{String}) ? comp_affected : [comp_affected]

    l_avail = zeros(max_time + 1, n_sectors)

    for comp in comp_affected
        vals = filter(row -> any(occursin.(comp, row.compartment)), df)[:, :value]
        vals = reshape(vals, (max_time + 1, n_sectors))
        scaling = diagm(scaling_affected[comp])
        l_avail += (vals * scaling)
        # prop of sector available
    end

    l_avail *= diagm(1.0 ./ n_workers)

    if combine_sectors
        sum(l_avail, dims = (2))
    else
        l_avail
    end
end

"""
    calc_consumption_avail(deaths::AbstractVector, phi::Real)

Calculate daily consumption availability from infection-avoidance behaviour.

Models the reduction in consumption (e.g., reduced shopping, dining out, travel) as
exponential decay driven by daily new deaths. On days with high mortality, consumers
avoid going out for discretionary purchases.

# Arguments
- `deaths::AbstractVector`: Cumulative death count time series (length n_days)
- `phi::Real`: Infection-avoidance scaling parameter. Larger values mean stronger
  consumption reduction in response to deaths (dimensionally, 1/deaths)

# Returns
`Vector{Float64}`: Daily consumption availability fractions, calculated as
`exp(-phi * new_deaths)` where `new_deaths = [0; diff(deaths)]`

# Example
```julia
cumulative_deaths = [0.0, 1.0, 3.0, 5.0, 5.0, 6.0]
phi = 0.01
avail = calc_consumption_avail(cumulative_deaths, phi)
# new_deaths: [0, 1, 2, 2, 0, 1]
# avail: [exp(0), exp(-0.01), exp(-0.02), exp(-0.02), exp(0), exp(-0.01)]
#      ≈ [1.0, 0.99, 0.98, 0.98, 1.0, 0.99]
```
"""
function calc_consumption_avail(deaths::AbstractVector, phi::Real)
    new_deaths = [0; diff(deaths)]
    return exp.(-phi .* new_deaths)
end

"""
    integrate_shock(t::AbstractVector, avail::AbstractVector)

Compute time-weighted average of a daily availability time series using trapezoidal integration.

Integrates the availability curve over time and normalizes by the total time span to produce
a single scalar shock value (typically in [0.0, 1.0]) suitable for use as a `ParameterShock`
scale factor.

# Arguments
- `t::AbstractVector`: Time vector (numeric, typically day-of-year or date-as-integer).
  Must be strictly increasing.
- `avail::AbstractVector`: Daily availability fractions, same length as `t`

# Returns
`Float64`: Time-weighted average availability, calculated as:
```
area_under_curve / (t[end] - (t[1] - 1.0))
```
where `area_under_curve` is computed using the trapezoidal rule.

The normalization `t[end] - (t[1] - 1.0)` represents the total time span including the first day.

# Example
```julia
t = [1.0, 2.0, 3.0, 4.0]
avail = [1.0, 0.95, 0.90, 0.90]
shock = integrate_shock(t, avail)
# Trapezoidal area ≈ (1.0 + 0.95)/2 + (0.95 + 0.90)/2 + (0.90 + 0.90)/2 = 2.8
# shock ≈ 2.8 / (4.0 - 0.0) = 0.7
```
"""
function integrate_shock(t::AbstractVector, avail::AbstractVector)
    # Trapezoidal integration
    dt = diff(t)
    area = sum((avail[1:(end - 1)] .+ avail[2:end]) ./ 2 .* dt)
    # Normalize by total time span (inclusive of first day)
    return area / (t[end] - (t[1] - 1.0))
end

end
