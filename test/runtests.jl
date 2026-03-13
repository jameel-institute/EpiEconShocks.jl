using EpiEconShocks
using Test

@testset "EpiEconShocks.jl" begin
    # tests for NamedArray helpers
    include("test_cluster_named_array.jl")
    include("test_cluster_gtap.jl")
end
