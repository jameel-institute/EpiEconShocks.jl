@testset "EpiHelpers.calc_labour_avail" begin
    # Load daedalus data
    df = CSV.read(joinpath(@__DIR__, "data", "data_daedalus.csv"), DataFrame)

    # Filter to working-age population and exclude non-working sectors
    df_work = filter(
        row -> row.age_group == "20-64" &&
               row.vaccine_group == "unvaccinated" &&
               row.econ_sector != "sector_00",
        df
    )

    n_adults = 1_000_000.0
    n_school = 500_000.0
    n_workers = 500_000.0

    # Test basic functionality with default parameters
    result = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school
    )

    @test isa(result, Matrix{Float64})
    n_sectors = length(unique(df_work.econ_sector))
    @test size(result) == (1, n_sectors)

    # Labour availability should be in [0, 1] range
    @test all(0.0 .<= result .<= 1.0)

    # Test with scalar scaling parameters
    result = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school,
        scaling_wfh = 0.8, scaling_care = 0.5, scaling_furl = 0.1
    )
    @test isa(result, Matrix{Float64})
    @test all(0.0 .<= result .<= 1.0)

    # Test with vector scaling parameters
    wfh_vec = fill(0.7, n_sectors)
    care_vec = fill(0.3, n_sectors)
    furl_vec = fill(0.2, n_sectors)

    result = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school;
        scaling_wfh = wfh_vec, scaling_care = care_vec, scaling_furl = furl_vec
    )
    @test isa(result, Matrix{Float64})
    @test size(result) == (n_time_points, n_sectors)
    @test all(0.0 .<= result .<= 1.0)

    # Test with vector n_workers
    n_workers_vec = fill(n_workers / n_sectors, n_sectors)
    result = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers_vec, n_adults, n_school
    )
    @test isa(result, Matrix{Float64})
    @test size(result) == (n_time_points, n_sectors)

    # Test zero epidemic scenario
    df_zero = DataFrame(
        time = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1],
        compartment = ["infect_symp", "infect_asymp", "dead",
            "hospitalised_recov", "hospitalised_death",
            "infect_symp", "infect_asymp", "dead", "hospitalised_recov", "hospitalised_death"],
        value = [0.0, 0.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 0.0, 0.0],
        econ_sector = ["sector_a", "sector_a", "sector_a", "sector_a", "sector_a",
            "sector_b", "sector_b", "sector_b", "sector_b", "sector_b"]
    )

    result_zero = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, 1000.0, 10000.0, 0.0;
        scaling_wfh = 0.0, scaling_care = 0.0, scaling_furl = 0.0
    )
    # With zero epidemic and no indirect effects, availability should be 1.0
    @test all(result_zero .≈ 1.0)
end

@testset "Labour availability errors" begin
    # Input validation tests
    # Load daedalus data
    df = CSV.read(joinpath(@__DIR__, "data", "data_daedalus.csv"), DataFrame)

    # Filter to working-age population and exclude non-working sectors
    df_work = filter(
        row -> row.age_group == "20-64" &&
               row.vaccine_group == "unvaccinated" &&
               row.econ_sector != "sector_00",
        df
    )

    n_adults = 1_000_000.0
    n_school = 500_000.0
    n_workers = 500_000.0
    n_sectors = length(unique(df_work.econ_sector))

    # Negative n_adults
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, -1000.0, n_school
    )

    # Negative n_school
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, -100.0
    )

    # Negative n_workers (scalar)
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, -100.0, n_adults, n_school
    )

    # Negative n_workers (vector element)
    bad_nw_vec = [-1.0; fill(10000.0, n_sectors - 1)]
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, bad_nw_vec, n_adults, n_school
    )

    # n_workers vector length mismatch
    wrong_length_nw = fill(1000.0, n_sectors + 1)
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, wrong_length_nw, n_adults, n_school
    )

    # scaling_wfh outside [0, 1] (too small)
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school; scaling_wfh = -0.1
    )

    # scaling_wfh outside [0, 1] (too large)
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school; scaling_wfh = 1.5
    )

    # scaling_care vector with invalid values
    bad_care_vec = [0.5, 1.5, 0.5]  # 1.5 is out of range
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school; scaling_care = bad_care_vec
    )

    # scaling_furl vector length mismatch
    wrong_furl_vec = fill(0.3, n_sectors + 1)
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school; scaling_furl = wrong_furl_vec
    )

    # scaling_affected with out-of-range values
    bad_scaling = EpiEconShocks.EpiHelpers.default_labour_scaling(n_sectors)
    bad_scaling["infect_symp"][1] = 1.5  # Out of range
    @test_throws ArgumentError EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school; scaling_affected = bad_scaling
    )
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
