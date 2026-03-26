# No module here
export ParameterShock

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
- `scale::Union{Float64, Vector{Float64}}`: The scaling factor ``> 0.0`` to apply.
    Pass a vector of the same length as `indices` to scale each index separately.
- `regions::Union{Nothing, String, Vector{String}}`: (Optional) Region indices to apply
  region-specific shocks. Leave as `nothing` for uniform regional scaling.
  - `nothing`: Apply scaling uniformly across all regions
  - `String`: Apply different scaling to a single region
  - `Vector{String}`: Apply different scaling to multiple regions
- `region_scale::Union{Nothing, Float64, Vector{Float64}}`: (Optional) Region-specific
  scaling factors. Required if `regions` is not `nothing`.
  - Pass a scalar to apply the same scale to all specified regions
  - Pass a vector of length `length(regions)` for per-region scaling

# Constructors

```julia
# Basic constructor: commodity-specific or uniform regional scaling
ParameterShock(parameter::String, indices, scale::Float64)

# Region-specific: apply different scaling to different regions
ParameterShock(parameter::String, indices, scale::Float64;
               regions::Union{String, Vector{String}}, region_scale::Union{Float64, Vector{Float64}})
```

# Examples

```julia
# Shock skilled and unskilled labor uniformly by 50%
ParameterShock("qe", ["skilled labour", "unskilled labour"], 0.5)

# Shock all rows of a parameter uniformly
ParameterShock("qe", nothing, 0.5)

# Apply different scaling to different regions (all commodities)
ParameterShock("qpa", nothing, 1.0; regions=["USA", "CHN"], region_scale=[0.95, 0.90])

# Region-specific shock to specific commodity
ParameterShock("qpa", "svces", 1.0; regions=["USA", "CHN"], region_scale=[0.95, 0.90])
```
"""
struct ParameterShock
    parameter::String
    indices::Union{Nothing, String, Vector{String}}
    scale::Union{Float64, Vector{Float64}}
    regions::Union{Nothing, String, Vector{String}}
    region_scale::Union{Nothing, Float64, Vector{Float64}}

    function ParameterShock(parameter, indices, scale;
                           regions=nothing, region_scale=nothing)
        # Validate commodity/endowment indices and scale
        if isa(indices, Vector{String}) &&
           (!isa(scale, Float64) && (length(scale) != length(indices)))
            throw(ArgumentError(
                "`scale` must be a scalar or the same length as `indices`"
            ))
        end
        if any(scale .< 0.0)
            throw(ArgumentError(
                "All values of scale must be > 0.0, got $scale"
            ))
        end

        # Validate region-specific scaling
        if !isnothing(regions) && isnothing(region_scale)
            throw(ArgumentError(
                "`region_scale` must be provided if `regions` is specified"
            ))
        end

        if !isnothing(region_scale)
            if any(region_scale .< 0.0)
                throw(ArgumentError(
                    "All values of region_scale must be > 0.0, got $region_scale"
                ))
            end
            if isa(regions, Vector{String}) &&
               (!isa(region_scale, Float64) && (length(region_scale) != length(regions)))
                throw(ArgumentError(
                    "`region_scale` must be a scalar or the same length as `regions`"
                ))
            end
        end

        new(parameter, indices, scale, regions, region_scale)
    end
end
