# No module here
export ParameterShock

"""
    ParameterShock

A public struct encoding a perturbation to a GTAP model parameter.

# Fields
- `parameter::String`: The name of the parameter in `model.data` to shock
- `indices::Union{Nothing, String, Vector{String}}`: Row indices to apply the shock to.
  - `nothing`: Apply to all rows
  - `String`: Apply to a single row
  - `Vector{String}`: Apply to multiple rows
- `scale::Float64`: The scaling factor in [0.0, 1.0] to apply to the parameter values

# Constructor

```julia
ParameterShock(parameter::String, indices, scale::Float64)
```

Raises `ArgumentError` if scale is not in [0.0, 1.0].

# Example

```julia
# Shock skilled and unskilled labor by 50%
ParameterShock("qe", ["skilled labor", "unskilled labor"], 0.5)

# Shock all rows of a parameter
ParameterShock("qe", nothing, 0.5)
```
"""
struct ParameterShock
    parameter::String
    indices::Union{Nothing, String, Vector{String}}
    scale::Float64

    function ParameterShock(parameter, indices, scale)
        if !(0.0 <= scale <= 1.0)
            throw(ArgumentError(
                "scale must be in the range [0.0, 1.0], got $scale"
            ))
        end

        new(parameter, indices, scale)
    end
end
