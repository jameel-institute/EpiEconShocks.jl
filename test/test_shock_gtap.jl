using Test
using EpiEconShocks

@testset "ParameterShock" begin
    # Test valid construction with vector indices
    shock = EpiEconShocks.ParameterShock("qe", ["skilled labor", "unskilled labor"], 0.5)
    @test shock.parameter == "qe"
    @test shock.indices == ["skilled labor", "unskilled labor"]
    @test shock.scale == 0.5

    # Test valid construction with nothing indices
    shock = EpiEconShocks.ParameterShock("qe", nothing, 0.5)
    @test shock.parameter == "qe"
    @test isnothing(shock.indices)
    @test shock.scale == 0.5

    # Test valid construction with single string index
    shock = EpiEconShocks.ParameterShock("qe", "skilled labor", 0.5)
    @test shock.parameter == "qe"
    @test shock.indices == "skilled labor"
    @test shock.scale == 0.5

    # Test boundary values
    shock = EpiEconShocks.ParameterShock("qe", nothing, 0.0)
    @test shock.scale == 0.0

    shock = EpiEconShocks.ParameterShock("qe", nothing, 1.0)
    @test shock.scale == 1.0

    # Test ArgumentError for scale > 1.0
    @test_throws ArgumentError EpiEconShocks.ParameterShock("qe", nothing, 1.1)

    # Test ArgumentError for scale < 0.0
    @test_throws ArgumentError EpiEconShocks.ParameterShock("qe", nothing, -0.1)
end

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
