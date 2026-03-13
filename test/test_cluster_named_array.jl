using Test
using NamedArrays
using EpiEconShocks

@testset "cluster_named_array" begin
    # Test basic clustering with multiple preserved indices
    @test begin
        x = ["a", "b", "c", "d"]
        x = NamedArray(x, x)
        result = EpiEconShocks.Helpers.cluster_named_array(x, ["a", "c"]; fill_value = "other")
        all(v -> v in ["a", "c", "other"], result) && count(x -> x == "other", result) == 2
    end

    # Test clustering with single preserved index
    @test begin
        x = ["a", "b", "c"]
        x = NamedArray(x, x)
        result = EpiEconShocks.Helpers.cluster_named_array(x, "b"; fill_value = "row")
        count(x -> x == "b", result) == 1 && all(v -> v in ["b", "row"], result)
    end

    # Test default fill_value
    @test begin
        x = ["x", "y", "z"]
        x = NamedArray(x, x)
        result = EpiEconShocks.Helpers.cluster_named_array(x, "y")
        "y" in result && count(x -> x == "XYZ", result) == 2
    end

    # Test preserving all indices
    @test begin
        x = ["a", "b", "c"]
        x = NamedArray(x, x)
        result = EpiEconShocks.Helpers.cluster_named_array(x, ["a", "b", "c"]; fill_value = "fill")
        all(v -> v in ["a", "b", "c"], result) && !("fill" in result)
    end

    # Test with custom fill_value
    @test begin
        x = ["p", "q", "r", "s"]
        x = NamedArray(x, x)
        result = EpiEconShocks.Helpers.cluster_named_array(x, ["p", "s"]; fill_value = "aggregated")
        all(v -> v in ["p", "s", "aggregated"], result) &&
            count(x -> x == "aggregated", result) == 2
    end

    # Test groups as Dict
    @test begin
        x = ["a", "b", "c", "d"]
        x = NamedArray(x, x)
        groups = Dict("g1" => ["b"], "g2" => ["d"])
        result = EpiEconShocks.Helpers.cluster_named_array(x, ["a", "c"]; fill_value = "row", groups = groups)
        result[1] == "a" && result[2] == "g1" && result[3] == "c" && result[4] == "g2"
    end

    # Test multiple groups
    @test begin
        x = ["a", "b", "c", "d", "e"]
        x = NamedArray(x, x)
        groups = Dict("group1" => ["b", "c"], "group2" => ["d", "e"])
        result = EpiEconShocks.Helpers.cluster_named_array(x, ["a"]; fill_value = "row", groups = groups)
        result[1] == "a" && result[2] == "group1" && result[3] == "group1" &&
            result[4] == "group2" && result[5] == "group2"
    end

    # Test groups = nothing (default behavior)
    @test begin
        x = ["a", "b", "c", "d"]
        x = NamedArray(x, x)
        result = EpiEconShocks.Helpers.cluster_named_array(
            x, ["a", "c"]; fill_value = "other", groups = nothing)
        result[1] == "a" && result[2] == "other" && result[3] == "c" && result[4] == "other"
    end

    # Test that groups takes precedence over fill_value
    @test begin
        x = ["a", "b", "c"]
        x = NamedArray(x, x)
        groups = Dict("special" => ["b"])
        result = EpiEconShocks.Helpers.cluster_named_array(x, ["a"]; fill_value = "fill", groups = groups)
        result[1] == "a" && result[2] == "special" && result[3] == "fill"
    end
end
