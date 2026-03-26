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

@testset "ParameterShock with region-specific scaling" begin
    # Test region-specific scaling with vector regions and vector scales
    shock = EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                        regions=["USA", "CHN"],
                                        region_scale=[0.95, 0.90])
    @test shock.parameter == "qpa"
    @test isnothing(shock.indices)
    @test shock.scale == 1.0
    @test shock.regions == ["USA", "CHN"]
    @test shock.region_scale == [0.95, 0.90]

    # Test region-specific scaling with string region and scalar scale
    shock = EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                        regions="USA",
                                        region_scale=0.95)
    @test shock.regions == "USA"
    @test shock.region_scale == 0.95

    # Test region-specific scaling with multiple indices and multiple regions
    shock = EpiEconShocks.ParameterShock("qpa", ["corn", "wheat"], 1.0;
                                        regions=["USA", "CHN", "IND"],
                                        region_scale=[0.95, 0.90, 0.85])
    @test shock.indices == ["corn", "wheat"]
    @test shock.regions == ["USA", "CHN", "IND"]
    @test shock.region_scale == [0.95, 0.90, 0.85]

    # Test region-specific scaling with uniform scale across regions
    shock = EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                        regions=["USA", "CHN"],
                                        region_scale=0.90)
    @test shock.region_scale == 0.90

    # Test ArgumentError when regions is specified but region_scale is missing
    @test_throws ArgumentError EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                                           regions="USA")

    # Test ArgumentError when regions is specified but region_scale is nothing
    @test_throws ArgumentError EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                                           regions=["USA", "CHN"],
                                                           region_scale=nothing)

    # Test ArgumentError when region_scale vector length doesn't match regions length
    @test_throws ArgumentError EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                                           regions=["USA", "CHN"],
                                                           region_scale=[0.95, 0.90, 0.85])

    # Test ArgumentError when region_scale contains negative values
    @test_throws ArgumentError EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                                           regions=["USA", "CHN"],
                                                           region_scale=[-0.1, 0.90])

    # Test boundary values for region_scale
    shock = EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                        regions=["USA", "CHN"],
                                        region_scale=[0.0, 1.0])
    @test shock.region_scale == [0.0, 1.0]

    # Test that region-specific scaling preserves other fields
    shock = EpiEconShocks.ParameterShock("qe", ["skilled labour", "unskilled labour"],
                                        [0.9, 0.8];
                                        regions=["USA", "CHN"],
                                        region_scale=[0.95, 0.90])
    @test shock.parameter == "qe"
    @test shock.indices == ["skilled labour", "unskilled labour"]
    @test shock.scale == [0.9, 0.8]
    @test shock.regions == ["USA", "CHN"]
    @test shock.region_scale == [0.95, 0.90]

    # Test that regions field is nothing by default
    shock = EpiEconShocks.ParameterShock("qe", nothing, 0.5)
    @test isnothing(shock.regions)
    @test isnothing(shock.region_scale)

    # Test single region with vector region_scale (should work)
    shock = EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                        regions="USA",
                                        region_scale=[0.95])
    @test shock.regions == "USA"
    @test shock.region_scale == [0.95]
end
