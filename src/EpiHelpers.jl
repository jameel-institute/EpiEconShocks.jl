
module EpiHelpers

using DataFrames

export calc_avail_labour, calc_labour_avail, calc_consumption_avail, integrate_shock

"""
    calc_avail_labour(
        data, scaling, N_work, wfh, p_furl;
        col_sector, col_mild, productivity_mild
    ) -> Vector{Float64}

Compute available labour supply for each row of a sector-stratified epidemiological
time series, accounting for illness absence, partial work-from-home (WFH) by mildly
symptomatic workers, and furlough.

Returns a `Vector{Float64}` of length `nrow(data)`. Each element is the fraction of
the sector's workforce available at that time step, typically in `[0, 1]`.

# Formula

For each row `(t, s)`:

```
absence(t, s)  = Σ_k [ base_scale_k × epi_k(t, s) ]
                 where the mild column uses effective scale:
                   base_scale_mild × (1 − wfh_s × productivity_mild)

avail(t, s)    = ( 1 − absence(t, s) / N_work_s ) × ( 1 − p_furl_s )
```

The mild-column adjustment models the fact that mildly symptomatic workers can
perform `wfh_s × productivity_mild` of their normal output remotely; only the
remaining fraction counts as an absence. `productivity_mild` (default 0.5) is the
proportion of WFH capacity accessible to a mildly ill worker.

Furloughed workers are assumed to be economically inactive regardless of epidemic
state, so `p_furl` is applied as a multiplicative reduction on top of illness
availability.

# Sector conventions

The function operates on **long-format** data: one row per `(time, sector)` pair.

When `N_work`, `wfh`, or `p_furl` is a vector, element `j` corresponds to the `j`-th
sector in the **sorted** order of the unique values in `col_sector`. For example, if
the sector column contains `["agri", "manuf"]`, sorted order is `["agri", "manuf"]`,
so index 1 → `"agri"` and index 2 → `"manuf"`. All vector arguments must have length
equal to the number of unique sectors in the data.

A scalar value applies the same parameter to all sectors.

# Arguments
- `data::DataFrame`: Long-format time series with one row per `(time, sector)` pair.
  Must contain the columns named in `scaling` and `col_sector`.
- `scaling::Dict`: Maps compartment column names (`Symbol` or `String`) to their base
  absence weights (all values must be scalar `Real`). Typical usage:
  `Dict(:prev_mldi => 1.0, :prev_sevi => 1.0, :occupancy_hosp => 1.0, :deaths => 1.0)`.
- `N_work::Union{Real, AbstractVector}`: Total workforce per sector. A scalar applies
  the same value to all sectors; a vector gives per-sector values in sorted sector order.
- `wfh::Union{Real, AbstractVector}`: WFH capability per sector — fraction of tasks
  performable remotely (0 = no WFH, 1 = fully remote). Same scalar/vector convention
  as `N_work`.
- `p_furl::Union{Real, AbstractVector}`: Proportion of the workforce furloughed per
  sector (0 = none, 1 = entire sector). Applied multiplicatively on top of illness
  availability. Same scalar/vector convention as `N_work`.

# Keyword arguments
- `col_sector::Symbol = :sector`: Column in `data` holding the sector identifier.
- `col_mild::Symbol = :prev_mldi`: Column in `scaling` for mildly symptomatic workers;
  the only compartment whose absence weight is modulated by `wfh`. If absent from
  `scaling`, WFH has no effect.
- `productivity_mild::Float64 = 0.5`: Fraction of WFH capacity accessible to a mildly
  ill worker. Effective absence weight for mild workers in sector `s` is
  `scaling[col_mild] × (1 − wfh_s × productivity_mild)`.

# Examples

Uniform parameters across all sectors:
```julia
data = DataFrame(
    sector        = ["agri", "agri", "manuf", "manuf"],
    date          = [1, 2, 1, 2],
    prev_mldi     = [100.0, 200.0, 300.0, 400.0],
    prev_sevi     = [10.0,   20.0,  30.0,  40.0],
)
scaling = Dict(:prev_mldi => 1.0, :prev_sevi => 1.0)
result = calc_avail_labour(data, scaling, 10_000.0, 0.0, 0.0)
# Row 1: absence = 100 + 10 = 110 → avail = 1 − 110/10000 = 0.989
```

Per-sector WFH and furlough via vectors (sorted sector order: ["agri", "manuf"]):
```julia
N_work = [5_000.0, 20_000.0]   # agri, manuf
wfh    = [0.1,     0.6]
p_furl = [0.0,     0.15]
result = calc_avail_labour(data, scaling, N_work, wfh, p_furl)
```
"""
function calc_avail_labour(
        data::DataFrame,
        scaling::Dict,
        N_work::Union{Real, AbstractVector},
        wfh::Union{Real, AbstractVector},
        p_furl::Union{Real, AbstractVector};
        col_sector::Symbol = :sector,
        col_mild::Symbol = :prev_mldi,
        productivity_mild::Float64 = 0.5
)
    use_vec = N_work isa AbstractVector || wfh isa AbstractVector ||
              p_furl isa AbstractVector
    sector_idx = use_vec ?
                 Dict(s => i for (i, s) in enumerate(sort(unique(data[!, col_sector])))) :
                 Dict{Any, Int}()

    result = Vector{Float64}(undef, nrow(data))
    col_mild_sym = Symbol(col_mild)

    for i in 1:nrow(data)
        s = data[i, col_sector]
        idx = use_vec ? sector_idx[s] : 0
        n_work_s = N_work isa AbstractVector ? Float64(N_work[idx]) : Float64(N_work)
        wfh_s = wfh isa AbstractVector ? Float64(wfh[idx]) : Float64(wfh)
        pfurl_s = p_furl isa AbstractVector ? Float64(p_furl[idx]) : Float64(p_furl)

        absence = 0.0
        for (col, base_scale) in scaling
            val = Float64(data[i, Symbol(col)])
            eff_scale = Symbol(col) == col_mild_sym ?
                        Float64(base_scale) * (1.0 - wfh_s * productivity_mild) :
                        Float64(base_scale)
            absence += eff_scale * val
        end

        avail_illness = 1.0 - absence / n_work_s
        result[i] = avail_illness * (1.0 - pfurl_s)
    end

    return result
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
function calc_labour_avail(epi_data::DataFrame, scaling::Dict, N_work::Real)
    absence = zeros(Float64, nrow(epi_data))
    for (col, scale) in scaling
        absence .+= Float64.(epi_data[!, Symbol(col)]) .* Float64(scale)
    end
    return 1.0 .- absence ./ N_work
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
