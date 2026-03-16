using Test
using EpiEconShocks

@testset "shock_gtap_example" begin
    # Test that shock_gtap_example runs without error
    @test begin
        model = EpiEconShocks.Example.get_example_model()
        result = EpiEconShocks.Example.shock_gtap_example(model, 0.5)
        !isnothing(result) && haskey(result, :y_by_q) && haskey(result, :ev_by_q)
    end
end
