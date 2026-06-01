
module EpiHelpers

using DataFrames
using LinearAlgebra
using Trapz

export calc_labour_avail, calc_consumption_avail, integrate_shock

function validate_scaling(scaling_dict::Dict, n_sectors::Real)::Dict
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

        for (i, v) in enumerate(val)
            if v < 0.0 || v > 1.0
                throw(ArgumentError(
                    "scaling_affected[$key][$i] must be in [0.0, 1.0], got $v"
                ))
            end
        end
    end

    return scaling_dict
end

function default_labour_scaling(n_sectors::Real = 45)::Dict
    return Dict(
        "infect_symp" => repeat([1.0], n_sectors),
        "infect_asymp" => repeat([0.5], n_sectors),
        "hospitalised_recov" => repeat([1.0], n_sectors),
        "hospitalised_death" => repeat([1.0], n_sectors),
        "dead" => repeat([1.0], n_sectors)
    )
end

function count_epi_affected(df::DataFrame,
        comp_affected::Union{String, Vector{String}} =
        ["infect_symp", "infect_asymp", "dead", "hospitalised_recov",
            "hospitalised_death"];
        scaling_affected::Union{Dict, Nothing} = nothing,
        exclude_deaths = false)

    # TODO: add input checks
    comp_epi_affected = exclude_deaths ?
                        comp_affected[comp_affected .!= "dead"] : comp_affected

    # reshaping
    timepoints = length(unique(df[:, "time"]))
    econ_sectors = length(unique(df[:, "econ_sector"]))
    reshape_dims = (econ_sectors, timepoints)

    # all epi affected are counted
    if isnothing(scaling_affected)
        df_epi_affected = filter(
            row -> any(occursin.(comp_epi_affected, row.compartment)), df)
        df_epi_affected = groupby(df_epi_affected, [:time, :econ_sector])
        df_epi_affected = combine(df_epi_affected, :value => (x -> sum(x)) => :value)

        # reshape to provide time x sector matrix
        value = df_epi_affected[:, :value]
        value = reshape(value, reshape_dims)'

        return value
    else
        epi_affected = ones(timepoints, econ_sectors)

        # explicit scaling of epi affected is provided
        for comp in comp_epi_affected
            vals = filter(row -> any(occursin.(comp, row.compartment)), df)[:, :value]
            vals = reshape(vals, (timepoints, econ_sectors))
            scaling = diagm(scaling_affected[comp])

            # labour available after scaling due to epi-state
            epi_affected += (vals * scaling)
        end

        return epi_affected
    end
end

"""
    calc_labour_avail(epi_data::DataFrame, scaling::Dict, N_work::Real) -> Vector{Float64}

Calculate daily labour availability from epidemiological compartment data.

Computes the fraction of the workforce still available at each time point as
`1 - weighted_absence / N_work`, where the weighted absence is the row-wise sum of
each compartment column multiplied by its scalar weight from `scaling`.
"""
calc_labour_avail = function (df::DataFrame,
        n_workers::Union{Float64, Vector{Float64}},
        n_adults::Real,
        n_school::Real,
        comp_affected::Union{String, Vector{String}} =
        ["infect_symp", "infect_asymp", "dead", "hospitalised_recov",
            "hospitalised_death"],
        scaling_affected::Dict = default_labour_scaling();
        scaling_wfh::Union{Float64, Vector{Float64}} = 0.5,
        scaling_care::Union{Float64, Vector{Float64}} = 0.27,
        scaling_furl::Union{Float64, Vector{Float64}} = 0.27,
        phi_eco::Float64 = 1.0,
        col_sector = "econ_sector"
)
    # Input validation
    if n_adults < 0.0
        throw(ArgumentError("n_adults must be >= 0.0, got $n_adults"))
    end

    if n_school < 0.0
        throw(ArgumentError("n_school must be >= 0.0, got $n_school"))
    end

    if isa(n_workers, Vector)
        for (i, val) in enumerate(n_workers)
            if val < 0.0
                throw(ArgumentError("n_workers[$i] must be >= 0.0, got $val"))
            end
        end
    else
        if n_workers < 0.0
            throw(ArgumentError("n_workers must be >= 0.0, got $n_workers"))
        end
    end

    times = unique(df[:, :time])
    max_time = maximum(times) # expect time col

    # compute derived qtys
    # assume data includes a non-working sector
    n_sectors = length(unique(df[:, col_sector])) - 1

    # Check n_workers vector length matches n_sectors
    if isa(n_workers, Vector) && length(n_workers) != n_sectors
        throw(ArgumentError("n_workers vector length must equal n_sectors ($n_sectors), got $(length(n_workers))"))
    end
    workers_as_prop = n_workers / n_adults # sector-wise workers as prop adults

    scaling_affected = validate_scaling(scaling_affected, n_sectors)

    # Validate scaling parameters (must be in [0.0, 1.0])
    for (name, scaling) in [
        ("scaling_wfh", scaling_wfh), ("scaling_care", scaling_care), (
            "scaling_furl", scaling_furl)]
        if isa(scaling, Vector)
            if length(scaling) != n_sectors
                throw(ArgumentError("$name vector length must equal n_sectors ($n_sectors), got $(length(scaling))"))
            end
            for (i, val) in enumerate(scaling)
                if val < 0.0 || val > 1.0
                    throw(ArgumentError("$name[$i] must be in [0.0, 1.0], got $val"))
                end
            end
        else
            if scaling < 0.0 || scaling > 1.0
                throw(ArgumentError("$name must be in [0.0, 1.0], got $scaling"))
            end
        end
    end

    comp_affected = isa(comp_affected, Vector{String}) ? comp_affected : [comp_affected]

    l_avail = zeros(max_time + 1, n_sectors)

    for comp in comp_affected
        vals = filter(row -> any(occursin.(comp, row.compartment)), df)[:, :value]
        vals = reshape(vals, (max_time + 1, n_sectors))
        scaling = diagm(scaling_affected[comp])

        # labour available after scaling due to epi-state
        l_avail += (vals * scaling)
    end

    # labour availability due to indirect effects
    ## furlough reduces economic loss
    # TODO: need to include time of NPIs
    l_avail *= isa(scaling_furl, Vector) ? diagm(1.0 .- scaling_furl) : 1.0 - scaling_furl

    ## caring for infected
    # count epi-affected
    n_epi_affected = count_epi_affected(df, comp_affected)

    # TODO: need to clarify intention on how scaling is applied
    # TODO: needs to output a times x econ sectors matrix
    l_notcar = 1.0 .-
               workers_as_prop .* (1.0 .- scaling_care) .*
               n_epi_affected ./ sum(n_workers)
    l_avail .*= l_notcar # element wise

    # TODO: need to include time of NPIs
    # TODO: need to clarify intention on how scaling is applied
    # TODO: check the output against workflow repo
    l_notscl = 1.0 .- workers_as_prop * (1.0 .- scaling_wfh) .*
                      n_school ./ sum(n_workers)
    l_avail .*= l_notscl

    return trapz(times, l_avail')' ./ (times[end] - times[begin])
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
