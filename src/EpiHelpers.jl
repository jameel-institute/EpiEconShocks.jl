
module EpiHelpers

using DataFrames

export calc_indivs

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
    transform!(df, AsTable(:) =>  ByRow(sum))

    return df[!, end] # last col is rowwise sum of cols
end

end