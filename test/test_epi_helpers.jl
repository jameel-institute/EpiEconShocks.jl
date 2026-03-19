@testset "EpiHelpers.calc_indivs" begin
    # Test basic functionality with simple data
    df = DataFrame(
        infected = [100, 150, 200],
        hospitalized = [10, 15, 20],
        deceased = [1, 2, 3]
    )
    scaling = Dict("infected" => 0.1, "hospitalized" => 1.0, "deceased" => 5.0)
    result = EpiEconShocks.EpiHelpers.calc_indivs(df, scaling)

    # Test that result is a vector
    @test isa(result, Vector)
    @test length(result) == 3

    # Test correct calculations: (infected * 0.1) + (hospitalized * 1.0) + (deceased * 5.0)
    # Time 1: (100 * 0.1) + (10 * 1.0) + (1 * 5.0) = 10 + 10 + 5 = 25
    # Time 2: (150 * 0.1) + (15 * 1.0) + (2 * 5.0) = 15 + 15 + 10 = 40
    # Time 3: (200 * 0.1) + (20 * 1.0) + (3 * 5.0) = 20 + 20 + 15 = 55
    @test result[1] ≈ 25.0
    @test result[2] ≈ 40.0
    @test result[3] ≈ 55.0

    # Test with single scaling factor
    df_single = DataFrame(compartment = [10, 20, 30])
    scaling_single = Dict("compartment" => 2.0)
    result_single = EpiEconShocks.EpiHelpers.calc_indivs(df_single, scaling_single)

    @test length(result_single) == 3
    @test result_single[1] ≈ 20.0
    @test result_single[2] ≈ 40.0
    @test result_single[3] ≈ 60.0

    # Test with scaling factor of 1.0 (no scaling)
    df_unscaled = DataFrame(a = [5, 10, 15], b = [3, 6, 9])
    scaling_one = Dict("a" => 1.0, "b" => 1.0)
    result_unscaled = EpiEconShocks.EpiHelpers.calc_indivs(df_unscaled, scaling_one)

    @test result_unscaled[1] ≈ 8.0
    @test result_unscaled[2] ≈ 16.0
    @test result_unscaled[3] ≈ 24.0

    # Test that only scaled columns are included
    df_extra = DataFrame(
        scaled_col = [10, 20, 30],
        unscaled_col = [100, 200, 300]  # Should be ignored
    )
    scaling_partial = Dict("scaled_col" => 0.5)
    result_partial = EpiEconShocks.EpiHelpers.calc_indivs(df_extra, scaling_partial)

    @test result_partial[1] ≈ 5.0
    @test result_partial[2] ≈ 10.0
    @test result_partial[3] ≈ 15.0

    # Test with floating point values
    df_float = DataFrame(
        compartment1 = [1.5, 2.5, 3.5],
        compartment2 = [0.5, 1.5, 2.5]
    )
    scaling_float = Dict("compartment1" => 0.3, "compartment2" => 0.7)
    result_float = EpiEconShocks.EpiHelpers.calc_indivs(df_float, scaling_float)

    @test result_float[1] ≈ 0.8 atol = 1e-10
    @test result_float[2] ≈ 1.8 atol = 1e-10
    @test result_float[3] ≈ 2.8 atol = 1e-10

    # Test that original dataframe is not modified
    df_original = DataFrame(x = [1, 2, 3], y = [4, 5, 6])
    df_copy = deepcopy(df_original)
    scaling_test = Dict("x" => 0.5, "y" => 2.0)
    _ = EpiEconShocks.EpiHelpers.calc_indivs(df_original, scaling_test)

    @test df_original == df_copy

    # Test with zero scaling
    df_zero = DataFrame(a = [10, 20], b = [5, 10])
    scaling_zero = Dict("a" => 0.0, "b" => 1.0)
    result_zero = EpiEconShocks.EpiHelpers.calc_indivs(df_zero, scaling_zero)

    @test result_zero[1] ≈ 5.0  # (10 * 0.0) + (5 * 1.0) = 5
    @test result_zero[2] ≈ 10.0  # (20 * 0.0) + (10 * 1.0) = 10
end
