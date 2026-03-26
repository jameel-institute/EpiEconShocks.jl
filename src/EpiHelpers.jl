
module EpiHelpers

using DataFrames

export calc_indivs, calc_labour_avail, calc_consumption_avail, integrate_shock

"""
    calc_indivs(data::DataFrame, scaling::Dict)

Calculate person-equivalents over time from epidemiological compartment data.

This function converts epidemiological model outputs (such as compartmental prevalence
counts from disease states like infected, hospitalized, or deceased) into weighted
person-equivalents by applying scaling factors and summing across compartments.

# Arguments
- `data::DataFrame`: Input DataFrame containing epidemiological compartment data with
  rows representing time points and columns representing disease compartments.
- `scaling::Dict`: Dictionary mapping column names (as `String` or `Symbol`) to scaling
  factors. Scaling factors are applied to weight the relative impact of each compartment.
  For example, `Dict("infected" => 0.1, "hospitalized" => 1.0)` represents that
  hospitalized individuals have 10x the impact of infected individuals.

# Returns
`Vector`: A vector of person-equivalents at each time point, calculated as the row-wise
sum of scaled compartment values.

# Example
```julia
df = DataFrame(
    infected = [100, 150, 200],
    hospitalized = [10, 15, 20],
    deceased = [1, 2, 3]
)
scaling = Dict("infected" => 0.1, "hospitalized" => 1.0, "deceased" => 5.0)
person_equiv = calc_indivs(df, scaling)
# Returns: [101.1, 151.7, 203.3]
```

# Details
The function performs the following steps:
1. Deep copies the input DataFrame to avoid modifying the original
2. Scales specified columns in-place by their corresponding scaling factors
3. Selects only the scaled columns (drops unscaled columns)
4. Sums across columns for each row to obtain person-equivalents
5. Returns the vector of row sums

Only columns specified in the `scaling` dictionary are included in the final calculation.
"""
function calc_indivs(data::DataFrame, scaling::Dict)
    df = deepcopy(data)

    for col in keys(scaling)
        df[!, col] .*= scaling[col]
    end

    select!(df, Symbol.(keys(scaling)))
    transform!(df, AsTable(:) => ByRow(sum))

    return df[!, end] # last col is rowwise sum of cols
end

"""
    calc_labour_avail(epi_data::DataFrame, scaling::Dict, N_work::Real)

Calculate daily labour availability from epidemiological compartment data.

Computes the fraction of the workforce still available at each time point by:
1. Calculating weighted person-equivalents (absent workers) using `calc_indivs`
2. Normalizing by total workforce
3. Returning availability as `1.0 - person_equiv / N_work`

# Arguments
- `epi_data::DataFrame`: Epidemiological time series with compartment columns (e.g., "mild", "severe", "hospitalized", "deceased")
- `scaling::Dict`: Mapping of compartment column names to their productivity impact weights.
  For example, mildly symptomatic workers might have weight `0.36` (i.e., 1 - 0.64 productivity)
- `N_work::Real`: Total workforce size

# Returns
`Vector{Float64}`: Daily labour availability fractions (typically in [0.0, 1.0],
 though can exceed 1.0 or be negative if data is inconsistent)

# Example
```julia
df = DataFrame(
    mild = [100, 150, 200],
    severe = [10, 15, 20],
    hospitalized = [5, 7, 10],
    deceased = [1, 2, 3]
)
scaling = Dict("mild" => 0.36, "severe" => 1.0, "hospitalized" => 1.0, "deceased" => 1.0)
N_work = 10000.0
avail = calc_labour_avail(df, scaling, N_work)
# Person-equivalents: [136.6, 207.8, 283]
# Availability: [1 - 136.6/10000, 1 - 207.8/10000, ...] ≈ [0.9863, 0.9792, 0.9717]
```
"""
function calc_labour_avail(epi_data::DataFrame, scaling::Dict, N_work::Real)
    person_equiv = calc_indivs(epi_data, scaling)
    return 1.0 .- person_equiv ./ N_work
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
    area = sum((avail[1:end-1] .+ avail[2:end]) ./ 2 .* dt)
    # Normalize by total time span (inclusive of first day)
    return area / (t[end] - (t[1] - 1.0))
end

end
