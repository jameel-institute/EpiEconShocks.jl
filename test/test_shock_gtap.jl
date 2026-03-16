using Test
using EpiEconShocks

@testset "shock_gtap" begin
    # Test that shock_gtap runs without error
    @test_skip begin
        model = EpiEconShocks.Example.get_example_model()
        result = shock_gtap(model, 0.5)
        !isnothing(result)
    end
end
