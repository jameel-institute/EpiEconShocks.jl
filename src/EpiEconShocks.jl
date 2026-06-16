module EpiEconShocks

using Reexport

include("Helpers.jl")
include("ModelInit.jl")
include("ParamShocks.jl")
include("ShockGtap.jl")
include("Example.jl")
include("Tools.jl")
include("EpiHelpers.jl")

@reexport using .Example
@reexport using .EpiHelpers

# Re-export functions from submodules for top-level access
export get_example_epi_data, calc_labour_avail, calc_consumption_avail,
       count_epi_affected, default_labour_scaling

end
