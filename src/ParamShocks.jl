export ParameterShock

using NamedArrays

"""
    ParameterShock

A public struct encoding a perturbation to a GTAP model parameter.

Supports both commodity/endowment-specific shocks and region-specific shocks.

# Fields
- `parameter::String`: The name of the parameter in `model.data` to shock
- `indices::Union{Nothing, String, Vector{String}}`: Row indices to apply the shock to
  (typically commodities or endowments).
  - `nothing`: Apply to all rows
  - `String`: Apply to a single row
  - `Vector{String}`: Apply to multiple rows
- `scale::Union{Float64, Vector{Float64}, NamedArray}`: The scaling factor
    ``> 0.0`` to apply. Pass a vector of the same length as `indices` to scale
    each index separately. Alternatively, pass a `NamedArray` with rows
    representing indices (sectors, endowments) and columns representing regions
    to shock specific regions.

# Constructors

```julia
# Basic constructor: commodity-specific or uniform regional scaling
ParameterShock(parameter::String, indices, scale::Float64)

# Region-specific: apply scaling to a commodity or endowment in specific regions
ParameterShock(parameter::String, indices, scale::NamedArray)
```

# Examples

```julia
# Shock skilled and unskilled labor uniformly by 50%
ParameterShock("qe", ["skilled labour", "unskilled labour"], 0.5)

# Shock all rows of a parameter uniformly
ParameterShock("qe", nothing, 0.5)

# Apply shocks to specific commodities or endowments in specific regions
mag = reshape([0.1, 0.2], 2, 1)
mag = NamedArray(mag, (["skilled labour", "unskilled labour"], ["chn"]))
ParameterShock("qpa", ["skilled labour", "unskilled labour"], mag)
```
"""
struct ParameterShock
    parameter::String
    indices::Union{Nothing, String, Vector{String}}
    scale::Union{Float64, Vector{Float64}, NamedArray}

    function ParameterShock(parameter, indices, scale)
        # Validate commodity/endowment indices and scale
        if isa(indices, Vector{String}) &&
           (!isa(scale, Float64) && (mod(length(scale), length(indices)) > 0))
            throw(ArgumentError(
                "`scale` must be a scalar or a multiple of `length(indices)`"
            ))
        end
        if any(scale .< 0.0)
            throw(ArgumentError(
                "All values of scale must be > 0.0, got $scale"
            ))
        end

        new(parameter, indices, scale)
    end
end
