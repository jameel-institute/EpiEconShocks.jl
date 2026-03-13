using Test
using NamedArrays
using EpiEconShocks

# NOTE: we cannot yet handle having EU countries separately from the EU
# NOTE: cluster_regions is specialised for GTAP data and expects the EU states

@testset "cluster_regions" begin
    # Test basic clustering with default preserve list
    @test begin
        regions = [["gbr", "usa", "chn", "ind"]; EpiEconShocks.Helpers.get_eu_states()]
        regions = NamedArray(regions, regions)
        result = EpiEconShocks.Helpers.cluster_regions(regions)
        all(x -> x in ["gbr", "usa", "chn", "eur", "row"], result)
    end

    # Test clustering with custom preserve list (without "eur")
    @test begin
        regions = [["gbr", "usa", "chn", "ind"]; EpiEconShocks.Helpers.get_eu_states()]
        regions = NamedArray(regions, regions)
        result = EpiEconShocks.Helpers.cluster_regions(regions, ["gbr", "usa"])
        all(x -> x in ["gbr", "usa", "row"], result)
    end

    # Test clustering with single preserved region
    @test begin
        regions = [["gbr", "usa", "chn", "ind"]; EpiEconShocks.Helpers.get_eu_states()]
        regions = NamedArray(regions, regions)
        result = EpiEconShocks.Helpers.cluster_regions(regions, "gbr")
        count(x -> x == "gbr", result) == 1 && all(x -> x in ["gbr", "row"], result)
    end

    # Test that non-preserved regions become "row"
    @test begin
        regions = ["gbr", "usa", "chn", "ind"]
        regions = NamedArray(regions, regions)
        result = EpiEconShocks.Helpers.cluster_regions(regions, ["gbr", "chn"])
        count(x -> x == "row", result) == 2
    end

    # Test that EU states are mapped to "eur" when "eur" is preserved
    @test begin
        regions = [["gbr", "usa", "chn", "ind"]; EpiEconShocks.Helpers.get_eu_states()]
        regions = NamedArray(regions, regions)
        result = EpiEconShocks.Helpers.cluster_regions(regions, ["gbr", "eur"])
        count(x -> x == "eur", result) >= 4 && "gbr" in result
    end

    # Test that "eur" is removed from preserve when expanded
    @test begin
        regions = [["gbr", "usa", "chn", "ind"]; EpiEconShocks.Helpers.get_eu_states()]
        regions = NamedArray(regions, regions)
        result = EpiEconShocks.Helpers.cluster_regions(regions, ["eur", "usa"])
        all(x -> x in ["eur", "usa", "row"], result)
    end
end
