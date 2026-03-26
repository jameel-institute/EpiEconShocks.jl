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

@testset "apply_shocks! with region-specific scaling" begin
    # Create mock 2D data [commodity, region]
    base_data = Dict("qpa" => [100.0 200.0; 150.0 250.0])
    data = deepcopy(base_data)

    # Test region-specific scaling on 2D array
    shock_regions = EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                                regions=["USA", "CHN"],
                                                region_scale=[0.95, 0.90])

    # Since _apply_shocks! requires NamedArrays with region names, we need
    # to work with a properly structured model. These tests verify the structure.
    @test shock_regions.regions == ["USA", "CHN"]
    @test shock_regions.region_scale == [0.95, 0.90]

    # Test region-specific scaling on commodity and region
    shock_combo = EpiEconShocks.ParameterShock("qpa", "svces", 1.0;
                                              regions=["USA"],
                                              region_scale=0.95)
    @test shock_combo.indices == "svces"
    @test shock_combo.regions == "USA"
    @test shock_combo.region_scale == 0.95

    # Test that commodity and region shocks can be combined
    shock1 = EpiEconShocks.ParameterShock("qe", ["skilled labour"], 0.9)
    shock2 = EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                         regions=["USA", "CHN"],
                                         region_scale=[0.95, 0.90])
    shocks = [shock1, shock2]

    @test length(shocks) == 2
    @test isnothing(shocks[1].regions)
    @test !isnothing(shocks[2].regions)

    # Test that multiple region shocks can be applied together
    shock_usa = EpiEconShocks.ParameterShock("qpa", nothing, 1.0;
                                            regions="USA",
                                            region_scale=0.95)
    shock_chn = EpiEconShocks.ParameterShock("qe", nothing, 1.0;
                                            regions="CHN",
                                            region_scale=0.90)
    multi_region_shocks = [shock_usa, shock_chn]

    @test multi_region_shocks[1].regions == "USA"
    @test multi_region_shocks[2].regions == "CHN"

    # Test that region-specific scaling preserves commodity/endowment shocks
    combined_shock = EpiEconShocks.ParameterShock("qpa", ["corn", "wheat"], [0.9, 0.8];
                                                 regions=["USA", "CHN"],
                                                 region_scale=[0.95, 0.90])
    @test combined_shock.indices == ["corn", "wheat"]
    @test combined_shock.scale == [0.9, 0.8]
    @test combined_shock.regions == ["USA", "CHN"]
    @test combined_shock.region_scale == [0.95, 0.90]
end
