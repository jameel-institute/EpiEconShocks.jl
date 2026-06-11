module EpiEconShocks

include("Helpers.jl")
include("ModelInit.jl")
include("ParamShocks.jl")
include("ShockGtap.jl")
include("Example.jl")
include("Tools.jl")
include("EpiHelpers.jl")

# Re-export functions from submodules for top-level access
export calc_labour_avail, calc_consumption_avail, get_example_epi_data

end
