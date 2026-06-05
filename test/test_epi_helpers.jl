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

    n_school = 5_000_000.0 # assume 5 million children
    n_workers = filter(
        row -> row.time == minimum(df_work[:, "time"]) &&
               row.compartment == "susceptible", df_work
    )[:, "value"]
    n_adults = sum(n_workers)

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
    @test size(result, 2) == n_sectors
    @test all(0.0 .<= result .<= 1.0)

    # Test zero epidemic scenario
    df_zero = DataFrame(
        (time = t, compartment = comp, econ_sector = "sector_" * esec) for
    t in 0:1 for comp in ["a", "b"] for esec in ["a", "b"])
    df_zero.value .= 0.0

    n_workers = fill(1000.0, 2)
    scaling_dummy = Dict(
        "a" => [1.0, 1.0],
        "b" => [0.27, 0.27]
    )
    n_adults = sum(n_workers)
    n_school = 500.0
    n_sectors = length(unique(df_work.econ_sector))

    result_zero = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, n_workers, n_adults, n_school, ["a", "b"];
        scaling_affected = scaling_dummy, scaling_wfh = 0.0, scaling_care = 0.0
    )
    # With zero epidemic and no indirect effects, availability should be 1.0
    @test all(result_zero .≈ 1.0)
end

@testset "Labour availability errors" begin
    # Input validation tests
    # Load daedalus data
    # Test zero epidemic scenario
    df_zero = DataFrame(
        (time = t, compartment = comp, econ_sector = "sector_" * esec) for
    t in 0:1 for comp in ["a", "b"] for esec in ["a", "b"])
    df_zero.value .= 0.0

    n_workers = fill(1000.0, 2)
    scaling_dummy = Dict(
        "a" => [1.0, 1.0],
        "b" => [0.27, 0.27]
    )

    n_adults = sum(n_workers)
    n_school = 500.0
    n_sectors = length(unique(df_zero.econ_sector))

    # Negative n_adults
    @test_throws ArgumentError("n_adults must be >= 0.0, got -1000.0") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, n_workers, -1000.0, n_school
    )

    # Negative n_school
    @test_throws ArgumentError("n_school must be >= 0.0, got -100.0") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, n_workers, n_adults, -100.0
    )

    # Negative n_workers (scalar)
    @test_throws ArgumentError("n_workers[1] must be >= 0.0, got -100.0") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, [-100.0], n_adults, n_school
    )

    # Negative n_workers (vector element)
    bad_nw_vec = [-1.0; fill(10000.0, n_sectors - 1)]
    @test_throws ArgumentError("n_workers[1] must be >= 0.0, got -1.0") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, bad_nw_vec, n_adults, n_school
    )

    # n_workers vector length mismatch
    wrong_length_nw = fill(1000.0, n_sectors + 1)
    @test_throws ArgumentError("n_workers vector length must equal n_sectors ($n_sectors), got $(length(wrong_length_nw))") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, wrong_length_nw, n_adults, n_school
    )

    # scaling_wfh outside [0, 1] (too small)
    @test_throws ArgumentError("scaling_wfh must be in [0.0, 1.0], got -0.1") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, n_workers, n_adults, n_school;
        scaling_affected = scaling_dummy, scaling_wfh = -0.1
    )

    # scaling_wfh outside [0, 1] (too large)
    @test_throws ArgumentError("scaling_wfh must be in [0.0, 1.0], got 1.5") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, n_workers, n_adults, n_school; scaling_affected = scaling_dummy, scaling_wfh = 1.5
    )

    # scaling_care vector with invalid values
    bad_care_vec = [0.5, 1.5]  # 1.5 is out of range
    @test_throws ArgumentError("scaling_care[2] must be in [0.0, 1.0], got 1.5") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, n_workers, n_adults, n_school;
        scaling_affected = scaling_dummy, scaling_care = bad_care_vec
    )

    # scaling_furl vector length mismatch
    wrong_furl_vec = fill(0.3, n_sectors + 1)
    @test_throws ArgumentError("scaling_furl vector length must equal n_sectors ($n_sectors), got $(length(wrong_furl_vec))") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, n_workers, n_adults, n_school;
        scaling_affected = scaling_dummy, scaling_furl = wrong_furl_vec
    )

    # scaling_affected with out-of-range values
    bad_scaling = EpiEconShocks.EpiHelpers.default_labour_scaling(n_sectors)
    bad_scaling["infect_symp"][1] = 1.5  # Out of range
    @test_throws ArgumentError("scaling_affected[infect_symp][1] must be in [0.0, 1.0], got 1.5") EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_zero, n_workers, n_adults, n_school; scaling_affected = bad_scaling
    )
end

@testset "EpiHelpers.calc_consumption_avail" begin
    phi = 0.01

    # Helper: build a single-sector DataFrame with given cumulative deaths
    function make_deaths_df(cum_deaths::Vector{Float64}, sector = "sector_a",
            comp = "dead")
        n = length(cum_deaths)
        DataFrame(
            time = collect(0:(n - 1)),
            compartment = fill(comp, n),
            econ_sector = fill(sector, n),
            value = cum_deaths
        )
    end

    # All new deaths zero → all availability 1.0
    df_zero = make_deaths_df([0.0, 0.0, 0.0, 0.0])
    result = EpiEconShocks.EpiHelpers.calc_consumption_avail(df_zero, phi)

    @test isa(result, Vector{Float64})
    @test length(result) == 4
    @test all(result .≈ 1.0)

    # Single death spike: cumulative [0, 0, 1, 1, 1] → new [0, 0, 1, 0, 0]
    df_spike = make_deaths_df([0.0, 0.0, 1.0, 1.0, 1.0])
    result_spike = EpiEconShocks.EpiHelpers.calc_consumption_avail(df_spike, phi)

    @test length(result_spike) == 5
    @test result_spike[1] ≈ exp(0.0)
    @test result_spike[2] ≈ exp(0.0)
    @test result_spike[3] ≈ exp(-phi * 1.0)
    @test result_spike[4] ≈ exp(0.0)
    @test result_spike[5] ≈ exp(0.0)

    # Multiple deaths: cumulative [0, 1, 3, 5, 5, 6] → new [0, 1, 2, 2, 0, 1]
    df_multi = make_deaths_df([0.0, 1.0, 3.0, 5.0, 5.0, 6.0])
    result_multi = EpiEconShocks.EpiHelpers.calc_consumption_avail(df_multi, phi)

    @test length(result_multi) == 6
    @test result_multi[1] ≈ exp(-0.01 * 0.0)
    @test result_multi[2] ≈ exp(-0.01 * 1.0)
    @test result_multi[3] ≈ exp(-0.01 * 2.0)
    @test result_multi[4] ≈ exp(-0.01 * 2.0)
    @test result_multi[5] ≈ exp(-0.01 * 0.0)
    @test result_multi[6] ≈ exp(-0.01 * 1.0)

    # Zero phi → no avoidance, all availability 1.0
    df_any = make_deaths_df([0.0, 1.0, 2.0, 3.0])
    result_zero_phi = EpiEconShocks.EpiHelpers.calc_consumption_avail(df_any, 0.0)
    @test all(result_zero_phi .≈ 1.0)

    # Large phi → strong avoidance
    # cumulative [0, 1, 2, 3] → new [0, 1, 1, 1]
    result_large_phi = EpiEconShocks.EpiHelpers.calc_consumption_avail(df_any, 1.0)
    @test result_large_phi[1] ≈ exp(0.0)
    @test result_large_phi[2] ≈ exp(-1.0)
    @test result_large_phi[3] ≈ exp(-1.0)

    # Deaths summed across sectors: two sectors with half the deaths each
    # sector_a cumulative: [0, 0.5, 1.0, 1.0]
    # sector_b cumulative: [0, 0.5, 2.0, 2.0]
    # total cumulative:    [0, 1.0, 3.0, 3.0] → new [0, 1, 2, 0]
    df_two_sectors = DataFrame(
        time = [0, 0, 1, 1, 2, 2, 3, 3],
        compartment = fill("dead", 8),
        econ_sector = repeat(["sector_a", "sector_b"], 4),
        value = [0.0, 0.0, 0.5, 0.5, 1.0, 2.0, 1.0, 2.0]
    )
    result_two = EpiEconShocks.EpiHelpers.calc_consumption_avail(df_two_sectors, phi)
    @test length(result_two) == 4
    @test result_two[1] ≈ exp(0.0)
    @test result_two[2] ≈ exp(-phi * 1.0)
    @test result_two[3] ≈ exp(-phi * 2.0)
    @test result_two[4] ≈ exp(0.0)

    # Custom compartment name via comp_deaths keyword
    df_custom = make_deaths_df([0.0, 2.0, 2.0], "sector_a", "mortality")
    result_custom = EpiEconShocks.EpiHelpers.calc_consumption_avail(
        df_custom, phi; comp_deaths = "mortality")
    @test result_custom[1] ≈ exp(0.0)
    @test result_custom[2] ≈ exp(-phi * 2.0)
    @test result_custom[3] ≈ exp(0.0)

    # Integration test with Daedalus example data
    df_daedalus = CSV.read(joinpath(@__DIR__, "data", "data_daedalus.csv"), DataFrame)
    result_daedalus = EpiEconShocks.EpiHelpers.calc_consumption_avail(df_daedalus, phi)
    @test isa(result_daedalus, Vector{Float64})
    @test all(0.0 .<= result_daedalus .<= 1.0)
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

@testset "EpiHelpers.calc_labour_avail with NPI timing" begin
    df = CSV.read(joinpath(@__DIR__, "data", "data_daedalus.csv"), DataFrame)
    df_work = filter(
        row -> row.age_group == "20-64" &&
               row.vaccine_group == "unvaccinated" &&
               row.econ_sector != "sector_00",
        df
    )

    n_school = 5_000_000.0
    n_workers = filter(
        row -> row.time == minimum(df_work[:, "time"]) &&
               row.compartment == "susceptible", df_work
    )[:, "value"]
    n_adults = sum(n_workers)

    # Test with economic closures
    econ_closures = [(5.0, 10.0), (20.0, 25.0)]
    result = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school;
        times_econ_closures = econ_closures
    )
    @test isa(result, Matrix{Float64})
    @test all(0.0 .<= result .<= 1.0)

    # Test with school closures
    school_closures = [(10.0, 15.0)]
    result = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school;
        times_school_closures = school_closures
    )
    @test isa(result, Matrix{Float64})
    @test all(0.0 .<= result .<= 1.0)

    # Test with both economic and school closures
    result = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school;
        times_econ_closures = econ_closures,
        times_school_closures = school_closures
    )
    @test isa(result, Matrix{Float64})
    @test all(0.0 .<= result .<= 1.0)

    # Test with no closures (should match default behaviour)
    result_no_closures = EpiEconShocks.EpiHelpers.calc_labour_avail(
        df_work, n_workers, n_adults, n_school;
        times_econ_closures = nothing,
        times_school_closures = nothing
    )
    @test isa(result_no_closures, Matrix{Float64})
end

@testset "Tools.is_npi_active" begin
    # Test basic functionality
    time = [1.0, 2.5, 5.0, 7.5, 10.0]
    bounds = [(2.0, 6.0), (8.0, 9.0)]
    result = EpiEconShocks.Tools.is_npi_active(time, bounds)

    @test isa(result, Vector{Float64})
    @test length(result) == length(time)
    @test result == [0.0, 1.0, 1.0, 0.0, 0.0]
    @test all(r in [0.0, 1.0] for r in result)

    # Test with overlapping intervals
    time_overlap = [1.0, 2.0, 3.0, 4.0, 5.0]
    bounds_overlap = [(1.5, 3.5), (2.5, 4.5)]
    result_overlap = EpiEconShocks.Tools.is_npi_active(time_overlap, bounds_overlap)

    @test result_overlap == [0.0, 1.0, 1.0, 1.0, 0.0]

    # Test boundary conditions
    time_boundary = [1.0, 2.0, 3.0]
    bounds_boundary = [(1.0, 2.0)]
    result_boundary = EpiEconShocks.Tools.is_npi_active(time_boundary, bounds_boundary)

    @test result_boundary == [1.0, 1.0, 0.0]

    # Test with single timepoint
    time_single = [5.0]
    bounds_single = [(4.0, 6.0)]
    result_single = EpiEconShocks.Tools.is_npi_active(time_single, bounds_single)

    @test result_single == [1.0]

    # Test with no timepoints in bounds
    time_outside = [0.5, 1.5, 9.5]
    bounds_outside = [(2.0, 3.0), (4.0, 5.0)]
    result_outside = EpiEconShocks.Tools.is_npi_active(time_outside, bounds_outside)

    @test all(result_outside .== 0.0)
end

@testset "Tools.is_npi_active input validation" begin
    # Test invalid bounds (lower > upper)
    time = [1.0, 2.0, 3.0]
    bad_bounds = [(3.0, 1.0)]

    @test_throws ArgumentError EpiEconShocks.Tools.is_npi_active(time, bad_bounds)

    # Test empty bounds
    empty_bounds = Tuple{Float64, Float64}[]

    @test_throws ArgumentError EpiEconShocks.Tools.is_npi_active(time, empty_bounds)

    # Test magnitude warning
    time_small = [1.0, 2.0]
    bounds_large = [(1e3, 2e3)]

    @test_warn r"Bounds and time vector differ" EpiEconShocks.Tools.is_npi_active(time_small, bounds_large)
end
