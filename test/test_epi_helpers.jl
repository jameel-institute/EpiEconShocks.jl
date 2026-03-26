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

@testset "EpiHelpers.calc_labour_avail" begin
    # Test basic functionality
    df = DataFrame(
        mild = [100, 200, 300],
        severe = [10, 20, 30],
        hospitalized = [5, 10, 15],
        deceased = [1, 2, 3]
    )
    scaling = Dict("mild" => 0.36, "severe" => 1.0, "hospitalized" => 1.0, "deceased" => 1.0)
    N_work = 10000.0

    result = EpiEconShocks.EpiHelpers.calc_labour_avail(df, scaling, N_work)

    # Verify result is a vector
    @test isa(result, Vector)
    @test length(result) == 3

    # Person-equivalents: (100*0.36) + (10*1) + (5*1) + (1*1) = 36 + 10 + 5 + 1 = 52
    # Availability: 1 - 52/10000 = 0.9948
    # Row 2: (200*0.36) + 20 + 10 + 2 = 72 + 20 + 10 + 2 = 104
    # Availability: 1 - 104/10000 = 0.9896
    # Row 3: (300*0.36) + 30 + 15 + 3 = 108 + 30 + 15 + 3 = 156
    # Availability: 1 - 156/10000 = 0.9844
    @test result[1] ≈ 0.9948
    @test result[2] ≈ 0.9896
    @test result[3] ≈ 0.9844

    # Test with full workforce absent
    df_absent = DataFrame(
        mild = [5000.0, 6000.0],
        severe = [3000.0, 4000.0],
        hospitalized = [1000.0, 1500.0],
        deceased = [1000.0, 500.0]
    )
    scaling_absent = Dict("mild" => 1.0, "severe" => 1.0, "hospitalized" => 1.0, "deceased" => 1.0)
    N_work = 1000.0
    result_absent = EpiEconShocks.EpiHelpers.calc_labour_avail(df_absent, scaling_absent, N_work)

    # Person-equivalents: 10000 and 12000, so availability = 1 - 10 and 1 - 12 (negative)
    @test result_absent[1] ≈ 1.0 - 10000.0 / 1000.0
    @test result_absent[2] ≈ 1.0 - 12000.0 / 1000.0

    # Test with zero epidemic (all columns zero)
    df_zero_epi = DataFrame(
        mild = [0, 0, 0],
        severe = [0, 0, 0],
        hospitalized = [0, 0, 0],
        deceased = [0, 0, 0]
    )
    scaling_zero = Dict("mild" => 0.5, "severe" => 1.0, "hospitalized" => 1.0, "deceased" => 1.0)
    result_zero = EpiEconShocks.EpiHelpers.calc_labour_avail(df_zero_epi, scaling_zero, 1000.0)

    @test result_zero[1] ≈ 1.0
    @test result_zero[2] ≈ 1.0
    @test result_zero[3] ≈ 1.0

    # Test that original DataFrame is not modified
    df_original = DataFrame(x = [100, 200], y = [10, 20])
    df_copy = deepcopy(df_original)
    scaling_test = Dict("x" => 0.5, "y" => 1.0)
    _ = EpiEconShocks.EpiHelpers.calc_labour_avail(df_original, scaling_test, 1000.0)

    @test df_original == df_copy

    # Test with single column
    df_single = DataFrame(infected = [50, 100, 150])
    scaling_single = Dict("infected" => 0.8)
    result_single = EpiEconShocks.EpiHelpers.calc_labour_avail(df_single, scaling_single, 1000.0)

    @test result_single[1] ≈ 1.0 - (50 * 0.8) / 1000.0
    @test result_single[2] ≈ 1.0 - (100 * 0.8) / 1000.0
    @test result_single[3] ≈ 1.0 - (150 * 0.8) / 1000.0
end

@testset "EpiHelpers.calc_consumption_avail" begin
    # Test with constant zero new deaths
    deaths_const = [0.0, 0.0, 0.0, 0.0]
    phi = 0.01
    result = EpiEconShocks.EpiHelpers.calc_consumption_avail(deaths_const, phi)

    @test isa(result, Vector)
    @test length(result) == 4
    # All new deaths are zero, so exp(0) = 1.0
    @test all(result .≈ 1.0)

    # Test with single death spike
    deaths_spike = [0.0, 0.0, 1.0, 1.0, 1.0]
    result_spike = EpiEconShocks.EpiHelpers.calc_consumption_avail(deaths_spike, phi)

    @test length(result_spike) == 5
    @test result_spike[1] ≈ exp(0.0)  # new_deaths[1] = 0
    @test result_spike[2] ≈ exp(0.0)  # new_deaths[2] = 0
    @test result_spike[3] ≈ exp(-phi * 1.0)  # new_deaths[3] = 1
    @test result_spike[4] ≈ exp(0.0)  # new_deaths[4] = 0
    @test result_spike[5] ≈ exp(0.0)  # new_deaths[5] = 0

    # Test with multiple deaths
    deaths_multi = [0.0, 1.0, 3.0, 5.0, 5.0, 6.0]
    result_multi = EpiEconShocks.EpiHelpers.calc_consumption_avail(deaths_multi, phi)

    @test length(result_multi) == 6
    # new_deaths: [0, 1, 2, 2, 0, 1]
    @test result_multi[1] ≈ exp(-0.01 * 0.0)
    @test result_multi[2] ≈ exp(-0.01 * 1.0)
    @test result_multi[3] ≈ exp(-0.01 * 2.0)
    @test result_multi[4] ≈ exp(-0.01 * 2.0)
    @test result_multi[5] ≈ exp(-0.01 * 0.0)
    @test result_multi[6] ≈ exp(-0.01 * 1.0)

    # Test with zero phi (no avoidance)
    deaths_any = [0.0, 1.0, 2.0, 3.0]
    result_zero_phi = EpiEconShocks.EpiHelpers.calc_consumption_avail(deaths_any, 0.0)

    # exp(-0.0 * x) = exp(0) = 1.0 for all x
    @test all(result_zero_phi .≈ 1.0)

    # Test with large phi (strong avoidance)
    # deaths_any = [0, 1, 2, 3], so new_deaths = [0, 1, 1, 1]
    phi_large = 1.0
    result_large_phi = EpiEconShocks.EpiHelpers.calc_consumption_avail(deaths_any, phi_large)

    @test result_large_phi[1] ≈ exp(0.0)
    @test result_large_phi[2] ≈ exp(-1.0)  # 1 new death on day 2
    @test result_large_phi[3] ≈ exp(-1.0)  # 1 new death on day 3
end

@testset "EpiHelpers.integrate_shock" begin
    # Test with constant availability of 1.0
    t_const = [1.0, 2.0, 3.0, 4.0]
    avail_const = [1.0, 1.0, 1.0, 1.0]
    result_const = EpiEconShocks.EpiHelpers.integrate_shock(t_const, avail_const)

    # Trapz area: (1+1)/2*1 + (1+1)/2*1 + (1+1)/2*1 = 3
    # Span: 4 - (1-1) = 4
    # Result: 3/4 = 0.75
    @test isa(result_const, Float64)
    @test result_const ≈ 0.75

    # Test with linear ramp from 1 to 0
    t_ramp = [1.0, 2.0, 3.0, 4.0]
    avail_ramp = [1.0, 2.0/3.0, 1.0/3.0, 0.0]
    result_ramp = EpiEconShocks.EpiHelpers.integrate_shock(t_ramp, avail_ramp)

    # Area under ramp (trapz): (1 + 2/3)/2 + (2/3 + 1/3)/2 + (1/3 + 0)/2
    #                        = 5/6 + 1/2 + 1/6 = 5/6 + 3/6 + 1/6 = 9/6 = 1.5
    # Time span: 4 - (1 - 1) = 4
    # Average: 1.5 / 4 = 0.375
    @test result_ramp ≈ 0.375 atol = 1e-10

    # Test with two-point line (trivial case)
    t_two = [1.0, 2.0]
    avail_two = [1.0, 0.5]
    result_two = EpiEconShocks.EpiHelpers.integrate_shock(t_two, avail_two)

    # Area: (1 + 0.5) / 2 * 1 = 0.75
    # Time span: 2 - 0 = 2
    # Average: 0.75 / 2 = 0.375
    @test result_two ≈ 0.375

    # Test with integer time values
    t_int = [100, 101, 102, 103]
    avail_int = [0.8, 0.8, 0.7, 0.7]
    result_int = EpiEconShocks.EpiHelpers.integrate_shock(t_int, avail_int)

    # Area: (0.8 + 0.8)/2 * 1 + (0.8 + 0.7)/2 * 1 + (0.7 + 0.7)/2 * 1 = 0.8 + 0.75 + 0.7 = 2.25
    # Time span: 103 - (100 - 1) = 4
    # Average: 2.25 / 4 = 0.5625
    @test result_int ≈ 0.5625 atol = 1e-10

    # Test with varying time steps
    t_vary = [1.0, 3.0, 4.0]
    avail_vary = [1.0, 0.5, 0.5]
    result_vary = EpiEconShocks.EpiHelpers.integrate_shock(t_vary, avail_vary)

    # Area: (1.0 + 0.5)/2 * 2 + (0.5 + 0.5)/2 * 1 = 1.5 + 0.5 = 2.0
    # Time span: 4 - (1 - 1) = 4
    # Average: 2.0 / 4 = 0.5
    @test result_vary ≈ 0.5
end
