module EpiEconShocks

using Reexport

include("Helpers.jl")
include("ModelInit.jl")
include("ParamShocks.jl")
include("ShockGtap.jl")
include("Example.jl")
include("Tools.jl")
include("EpiHelpers.jl")
include("LtCosts.jl")

@reexport using .Example
@reexport using .EpiHelpers
@reexport using .LtCosts

# Re-export functions from submodules for top-level access
export get_example_epi_data, calc_labour_avail, calc_consumption_avail,
       count_epi_affected, default_labour_scaling, calc_hca_cost, calc_fca_cost

end
