using CSV
using DataFrames
using EpiEconShocks
using NamedArrays
using Test

@testset "EpiEconShocks.jl" begin
    # tests for NamedArray helpers
    include("test_cluster_named_array.jl")
    include("test_cluster_gtap.jl")
    # tests for shock functions
    include("test_shock_gtap_example.jl")
    include("test_shock_gtap.jl")
    include("test_compare_gtaps.jl")
    # tests for structs
    include("test_struct_paramShock.jl")
    # tests for EpiHelpers
    include("test_epi_helpers.jl")
end
