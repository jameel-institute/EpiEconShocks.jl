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

    # Test ArgumentError for scale < 0.0
    @test_throws ArgumentError EpiEconShocks.ParameterShock("qe", nothing, -0.1)

    # Test valid construction with vector scale
    shock = EpiEconShocks.ParameterShock("qe", ["skilled labor", "unskilled labor"], [
        0.5, 0.7])
    @test shock.parameter == "qe"
    @test shock.indices == ["skilled labor", "unskilled labor"]
    @test shock.scale == [0.5, 0.7]

    # Test valid vector scale with boundary values
    shock = EpiEconShocks.ParameterShock("qe", ["a", "b", "c"], [0.0, 0.5, 1.0])
    @test shock.scale == [0.0, 0.5, 1.0]

    # Test ArgumentError when scale vector length doesn't match indices length
    @test_throws ArgumentError EpiEconShocks.ParameterShock("qe", ["a", "b"], [
        0.5, 0.6, 0.7])

    # Test ArgumentError when scale vector contains negative values
    @test_throws ArgumentError EpiEconShocks.ParameterShock("qe", ["a", "b"], [0.5, -0.1])

    # Test valid construction with scalar scale and nothing indices still works
    shock = EpiEconShocks.ParameterShock("qe", nothing, 0.75)
    @test shock.scale == 0.75

    # Test valid construction with scalar scale and string index still works
    shock = EpiEconShocks.ParameterShock("qpa", "svces", 0.2)
    @test shock.scale == 0.2
end

# some very basic tests for NamedArray as scaling factors
@testset "ParameterShock with region-specific scaling" begin
    # Create mock 2D data [commodity, region]
    base_data = Dict("qpa" => [100.0 200.0; 150.0 250.0])
    data = deepcopy(base_data)

    # Test region-specific scaling on 2D array
    mag = reshape([0.95, 0.90], 1, 2)
    mag = NamedArray(mag, ([""], ["usa", "chn"]))
    shock_regions = EpiEconShocks.ParameterShock("qpa", nothing, mag)

    @test shock_regions.indices == nothing
    @test shock_regions.scale == mag
end
