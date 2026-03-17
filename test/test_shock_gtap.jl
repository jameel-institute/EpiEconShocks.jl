using Test
using EpiEconShocks

@testset "shock_gtap" begin
    # Test that shock_gtap runs without error with ParameterShock vector
    @test_skip begin
        labour_shock = EpiEconShocks.ParameterShock(
            "qe", ["skilled labor", "unskilled labor"], 0.5)
        example_model = EpiEconShocks.Example.get_example_model()
        result = EpiEconShocks.shock_gtap(example_model, [labour_shock])
        !isnothing(result)
    end
end
