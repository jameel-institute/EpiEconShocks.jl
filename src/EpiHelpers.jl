
module EpiHelpers

export calc_labour_avail, calc_consumption_avail, integrate_shock

using ..Tools

using DataFrames
using LinearAlgebra
using Trapz

"""
    validate_scaling(scaling_dict::Dict, n_sectors::Real)::Dict

Validate compartment-specific scaling factors for epidemiological data.

Ensures that each scaling entry is a `Vector{Float64}` with length matching the 
number of sectors and all values in the valid range [0.0, 1.0].

# Arguments
- `scaling_dict::Dict`: Dictionary mapping compartment names (strings) to
    scaling vectors
- `n_sectors::Real`: Expected number of economic sectors

# Returns
- `Dict`: The validated scaling dictionary (unchanged if all checks pass)

# Raises
- `ArgumentError`: if any scaling vector is not of type `Vector{Float64}`, has
    incorrect length, or contains values outside [0.0, 1.0]
"""
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

"""
    default_labour_scaling(n_sectors::Real = 45)::Dict

Generate default compartment-specific scaling factors for labour availability
calculations. This function is set up to work with Daedalus model outputs with
corresponding epidemiological compartments.

The default scaling reflects the productivity loss associated with each
epidemiological state:
- Symptomatic infection: 1.0
- Asymptomatic infection: 0.5
- Hospitalised (recovery): 1.0
- Hospitalised (death): 1.0
- Dead: 1.0

Each scaling factor is replicated across all sectors, assuming uniform impact.

# Arguments
- `n_sectors::Real`: Number of economic sectors (default: 45)

# Returns
- `Dict`: Dictionary mapping compartment names to vectors of scaling factors
(one per sector). Keys match Daedalus compartments where individuals are
expected to have a reduction in productivity.
"""
function default_labour_scaling(n_sectors::Real = 45)::Dict
    return Dict(
        "infect_symp" => repeat([1.0], n_sectors),
        "infect_asymp" => repeat([0.5], n_sectors),
        "hospitalised_recov" => repeat([1.0], n_sectors),
        "hospitalised_death" => repeat([1.0], n_sectors),
        "dead" => repeat([1.0], n_sectors)
    )
end

"""
    count_epi_affected(df::DataFrame, comp_affected;
                       col_sector, scaling_affected, exclude_deaths) -> Matrix{Float64}

Count epidemiologically affected individuals by time and sector, with optional
scaling per compartment. This function is set up to deal with Daedalus model
outputs by default. Used internally in `calc_labour_avail`.

Filters epidemiological data to specified compartments and aggregates by time
and sector. Can optionally apply compartment-specific scaling factors
(e.g., to account for productivity of asymptomatic cases) and exclude deaths
from the count.

# Arguments
- `df::DataFrame`: Long-format epidemiological data with columns `time`,
    `compartment`, `value`, and a sector column
- `comp_affected::Union{String, Vector{String}}`: Compartments to include
    (default: infectious and hospitalised states, plus deaths)

# Keyword Arguments
- `col_sector::String`: Name of the sector column in `df`
    (default: `"econ_sector"`)
- `scaling_affected::Union{Dict, Nothing}`: Optional dictionary mapping
    compartment names to scaling vectors (one factor per sector). If provided,
    each compartment's values are scaled before summing (default: `nothing`,
    count all affected individuals equally)
- `exclude_deaths::Bool`: If `true`, exclude "dead" compartment from count
    (default: `false`)

# Returns
- `Matrix{Float64}`: Time-indexed matrix of shape (n_timepoints, n_sectors)
    with counts of affected for each time–sector combination.

# Notes
- When `scaling_affected` is provided, compartments are scaled by the relevant
    scaling vector before summing.
- When `scaling_affected` is `nothing`, affected individuals are returned as
    raw counts.
"""
function count_epi_affected(df::DataFrame,
        comp_affected::Union{String, Vector{String}} =
        ["infect_symp", "infect_asymp", "dead", "hospitalised_recov",
            "hospitalised_death"];
        col_sector::String = "econ_sector",
        scaling_affected::Union{Dict, Nothing} = nothing,
        exclude_deaths::Bool = false)::Matrix{Float64}
    comp_epi_affected = exclude_deaths ?
                        comp_affected[comp_affected .!= "dead"] : comp_affected

    timepoints = length(unique(df[:, "time"]))
    econ_sectors = length(unique(df[:, col_sector]))

    if isnothing(scaling_affected)
        df_epi_affected = filter(
            row -> any(occursin.(comp_epi_affected, row.compartment)), df)
        df_epi_affected = groupby(df_epi_affected, [:time, Symbol(col_sector)])
        df_epi_affected = combine(df_epi_affected, :value => (x -> sum(x)) => :value)

        value = df_epi_affected[:, :value]
        return reshape(value, timepoints, econ_sectors)
    else
        epi_affected = zeros(timepoints, econ_sectors)

        for comp in comp_epi_affected
            vals = filter(row -> any(occursin.(comp, row.compartment)), df)[:, :value]
            vals = reshape(vals, (timepoints, econ_sectors))
            scaling = diagm(scaling_affected[comp])
            epi_affected += (vals * scaling)
        end

        return epi_affected
    end
end

"""
    calc_labour_avail(df::DataFrame, n_workers, n_adults, n_school,
                      comp_affected; scaling_affected, times_econ_closures,
                      times_school_closures, scaling_wfh, scaling_care,
                      scaling_furl, col_sector) -> Matrix{Float64}

Calculate daily labour availability from epidemiological compartment data.

Computes time-weighted average labour availability by integrating 
epidemiological compartment counts with sector-specific parameters for
work-from-home capability, care responsibilities, and economic closures.

# Arguments
- `df::DataFrame`: Long-format epidemiological data with columns `time`, 
    `compartment`, `value`, and a sector column (default "econ_sector")
- `n_workers::Vector{Float64}`: Number of workers per sector.
    If scalar, applied uniformly; if vector, element `j` corresponds to sector
    `j` in sorted order
- `n_adults::Real`: Total adult population (non-negative)
- `n_school::Real`: School-age population (non-negative)
- `comp_affected::Union{String, Vector{String}}`: Compartments representing
    workforce absence (default: `["infect_symp", "infect_asymp", "dead", 
    "hospitalised_recov", "hospitalised_death"]`)

# Keyword Arguments
- `scaling_affected::Dict`: Scaling weights for each compartment
    (default: `default_labour_scaling()`)
- `times_econ_closures::Union{nothing, Vector{Tuple{Float64, Float64}}}`: Time
    intervals of economic closures as (start, end) tuples. `nothing` means no
    closures
- `times_school_closures::Union{nothing, Vector{Tuple{Float64, Float64}}}`: Time
    intervals of school closures. `nothing` means no closures
- `scaling_wfh::Union{Float64, Vector{Float64}}`: Work-from-home capability
    (scalar or per-sector), must be in [0.0, 1.0] (default: 0.27)
- `scaling_care::Union{Float64, Vector{Float64}}`: Fraction of workers
    unavailable due to care duties (scalar or per-sector), must be in [0.0, 1.0]
    (default: 0.27)
- `scaling_furl::Union{Float64, Vector{Float64}}`: Furlough rate reducing
    economic closure impact (scalar or per-sector), must be in [0.0, 1.0]
    (default: 0.28)
- `col_sector::String`: Name of sector column in `df` (default: `"econ_sector"`)

# Returns
`Vector{Float64}`: Time-weighted average labour availability per sector

# Validation
- `n_adults`, `n_school`, and `n_workers` must be non-negative
- Vector `n_workers` length must match number of working sectors in data
- `scaling_wfh`, `scaling_care`, `scaling_furl` must be in [0.0, 1.0]
- Vector scaling parameters must match number of sectors
"""
calc_labour_avail = function (df::DataFrame,
        n_workers::Vector{Float64},
        n_adults::Real,
        n_school::Real,
        comp_affected::Union{String, Vector{String}} =
        ["infect_symp", "infect_asymp", "dead", "hospitalised_recov",
            "hospitalised_death"];
        scaling_affected::Dict = default_labour_scaling(),
        times_econ_closures::Union{Nothing, Vector{Tuple{Float64, Float64}}} = nothing,
        times_school_closures::Union{Nothing, Vector{Tuple{Float64, Float64}}} = nothing,
        scaling_wfh::Union{Float64, Vector{Float64}} = 0.27,
        scaling_care::Union{Float64, Vector{Float64}} = 0.27,
        scaling_furl::Union{Float64, Vector{Float64}} = 0.28,
        col_sector::String = "econ_sector"
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

    times = float.(unique(df[:, :time]))
    econ_closures = isnothing(times_econ_closures) ? times .* 0.0 :
                    is_npi_active(times, times_econ_closures)
    school_closures = isnothing(times_school_closures) ? times .* 0.0 :
                      is_npi_active(times, times_school_closures)
    max_time = Int(maximum(times)) # expect time col

    # compute derived qtys
    # assume data only includes working-age indivs who are all in an econ sector
    n_sectors = length(unique(df[:, col_sector]))

    # Check n_workers vector length matches n_sectors
    if isa(n_workers, Vector) && length(n_workers) != n_sectors
        throw(ArgumentError("n_workers vector length must equal n_sectors ($n_sectors), got $(length(n_workers))"))
    end

    workers_as_prop = n_workers / n_adults # sector-wise workers as prop adults

    # TODO: allow single sector but multiple scaling where uniform distribution across sectors assumed
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

    # convert scaling to vectors if not already
    scaling_wfh = isa(scaling_wfh, Float64) ? repeat([scaling_wfh], n_sectors) :
                  scaling_wfh
    scaling_care = isa(scaling_care, Float64) ? repeat([scaling_care], n_sectors) :
                   scaling_care
    scaling_furl = isa(scaling_furl, Float64) ? repeat([scaling_furl], n_sectors) :
                   scaling_furl

    comp_affected = isa(comp_affected, Vector{String}) ? comp_affected : [comp_affected]

    l_avail = zeros(max_time + 1, n_sectors)

    ## labour available after direct infection effect
    l_avail = ones(max_time + 1, n_sectors) -
              count_epi_affected(
        df, comp_affected, scaling_affected = scaling_affected,
        col_sector = col_sector) ./ reshape(n_workers, (1, n_sectors))

    ## furlough reduces economic loss
    econ_closures_col = reshape(econ_closures, :, 1)
    scaling_furl_effect = isa(scaling_furl, Vector) ? (1.0 .- scaling_furl)' :
                          (1.0 .- scaling_furl)
    l_notecl = 1.0 .- econ_closures_col .* scaling_furl_effect

    ## caring for infected
    # scale epi_affected by caregiving productivity coeff
    scaling_affected["infect_asymp"] = scaling_care
    n_epi_affected = count_epi_affected(df, comp_affected,
        exclude_deaths = true, scaling_affected = scaling_affected, col_sector = col_sector)
    p_epi_affected = n_epi_affected / sum(n_workers)

    ## scaling due to caring for infected
    l_notcar = 1.0 .- sum(workers_as_prop) .* p_epi_affected

    ## scaling due to caring for school-age children
    school_closures_col = reshape(school_closures, :, 1)
    p_schoolage_caring = reshape(
        workers_as_prop .* (1.0 .- scaling_wfh), 1, n_sectors)
    l_notscl = 1.0 .-
               p_schoolage_caring .*
               (n_school ./ sum(n_workers)) .* school_closures_col

    l_avail .*= (l_notcar .* l_notscl .* l_notecl)

    return trapz(times, l_avail')' ./ (times[end] - times[begin])
end

"""
    calc_consumption_avail(df::DataFrame, phi::Real;
                           comp_deaths, col_sector) -> Vector{Float64}

Calculate daily consumption availability from infection-avoidance behaviour.

Models the reduction in consumption as exponential decay driven by daily 
new deaths. Deaths are aggregated across economic sectors for each timepoint.
This function is set up to deal with Daedalus-model type outputs.

# Arguments
- `df::DataFrame`: Long-format epidemiological data with columns `time`,
    `compartment`, `value`, and a sector column (default `"econ_sector"`)
- `phi::Real`: Infection-avoidance scaling parameter. Larger values mean stronger
  consumption reduction in response to deaths (dimensionally, 1/deaths)

# Keyword Arguments
- `comp_deaths::Union{String, Vector{String}}`: Compartment name(s) representing
    cumulative deaths (default: `"dead"`)
- `col_sector::String`: Name of the sector column in `df` (default: `"econ_sector"`)

# Returns
`Vector{Float64}`: Daily consumption availability fractions of length n_timepoints,
calculated as `exp(-phi * new_deaths)` where `new_deaths = [0; diff(cumulative_deaths)]`
and `cumulative_deaths` is the sum of the deaths compartment(s) across all sectors.

# Example
```julia
df = get_example_epi_data()
phi = 0.01
avail = calc_consumption_avail(df, phi)
```
"""
function calc_consumption_avail(df::DataFrame, phi::Real;
        comp_deaths::Union{String, Vector{String}} = "dead",
        col_sector::String = "econ_sector")
    comp_deaths_vec = isa(comp_deaths, String) ? [comp_deaths] : comp_deaths

    # count_epi_affected returns (n_timepoints × n_sectors); sum across sectors
    deaths_matrix = count_epi_affected(df, comp_deaths_vec, col_sector = col_sector)
    cumulative_deaths = vec(sum(deaths_matrix, dims = 2))

    new_deaths = [0; diff(cumulative_deaths)]
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
