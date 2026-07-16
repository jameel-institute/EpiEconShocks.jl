@testset "Counting epi affected works: no scaling" begin
    df = get_example_epi_data()
    n_sectors = 45 # default for daedalus data
    n_time = Int(length(unique(df.time)))
    filter!(x -> x.age_group == "20-64" && x.econ_sector != "sector_00", df)

    # overall sum is correct for a single compartment
    count_manual = sum(
        filter(x -> x.compartment == "dead", df)[:, "value"]
    )

    count = count_epi_affected(df, "dead")

    @test isa(count, Matrix{Float64})
    @test size(count) == (n_time, n_sectors)
    @test all(isfinite.(count))
    @test sum(count) ≈ count_manual

    # timewise sums are correct
    count_manual = sum(
        filter(x -> x.compartment == "dead" &&
                    x.time ≈ maximum(df.time), df)[:, "value"]
    )
    count = sum(count_epi_affected(df, "dead")[n_time, :])
    known_val = n_sectors * (maximum(df.time) * 100.0 + 1.0)
    @test count ≈ count_manual
    @test count ≈ known_val
end

@testset "Counting epi affected works: scaling by epi compartment" begin
    df = get_example_epi_data()
    n_sectors = 45 # default for daedalus data
    n_time = Int(length(unique(df.time)))
    filter!(x -> x.age_group == "20-64" && x.econ_sector != "sector_00", df)

    # manual - transformation is automatic in calc_labour_avail
    scaling = Dict(
        "dead" => repeat([1.0], n_sectors),
        "infect_asymp" => repeat([0.0], n_sectors)
    )
    # overall sum is correct for a single compartment
    count_manual = sum(
        filter(x -> x.compartment in ("dead", "infect_asymp"), df)[:, "value"]
    )

    count = count_epi_affected(df, ["dead", "infect_asymp"], scaling_affected = scaling)

    @test isa(count, Matrix{Float64})
    @test size(count) == (n_time, n_sectors)
    @test all(isfinite.(count))
    @test sum(count) ≈ count_manual / 2.0 # manual count doubles value

    # timewise sums are correct
    count_manual = sum(
        filter(
        x -> x.compartment in ("dead", "infect_asymp") &&
             x.time ≈ maximum(df.time), df)[:, "value"]
    )
    count = sum(count_epi_affected(df, ["dead", "infect_asymp"], scaling_affected = scaling)[n_time, :])
    known_val = n_sectors * (maximum(df.time) * 100.0 + 1.0)
    @test count ≈ count_manual / 2.0
    @test count ≈ known_val
end

@testset "EpiHelpers.calc_labour_avail" begin
    # Load daedalus data
    df = get_example_epi_data()

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
    result = calc_labour_avail(
        df, n_workers, n_adults, n_school
    )

    @test isa(result, Matrix{Float64})
    n_sectors = length(unique(df_work.econ_sector))
    @test size(result) == (1, n_sectors)

    # Labour availability should be in [0, 1] range
    @test all(0.0 .<= result .<= 1.0)

    # Test with scalar scaling parameters
    result = calc_labour_avail(
        df, n_workers, n_adults, n_school,
        scaling_wfh = 0.8, scaling_care = 0.5, scaling_furl = 0.1
    )
    @test isa(result, Matrix{Float64})
    @test all(0.0 .<= result .<= 1.0)

    # Test with vector scaling parameters
    wfh_vec = fill(0.7, n_sectors)
    care_vec = fill(0.3, n_sectors)
    furl_vec = fill(0.2, n_sectors)

    result = calc_labour_avail(
        df, n_workers, n_adults, n_school;
        scaling_wfh = wfh_vec, scaling_care = care_vec, scaling_furl = furl_vec
    )
    @test isa(result, Matrix{Float64})
    @test size(result, 2) == n_sectors
    @test all(0.0 .<= result .<= 1.0)

    # Test zero epidemic scenario
    df_zero = copy(df)
    transform!(df_zero,
        [:compartment,
            :value] => ByRow((comp,
            val) -> comp in ("infect_symp", "infect_asymp", "hospitalised_recov",
            "hospitalised_death", "dead") ? 0.0 : val) => :value)

    result_zero = calc_labour_avail(df_zero, n_workers, n_adults, n_school)
    # With zero epidemic and no indirect effects, availability should be 1.0
    @test all(result_zero .≈ 1.0)
end

@testset "EpiHelpers.calc_labour_avail with NPI timing" begin
    df = get_example_epi_data()
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
    result = calc_labour_avail(
        df, n_workers, n_adults, n_school;
        times_econ_closures = econ_closures
    )
    @test isa(result, Matrix{Float64})
    @test all(0.0 .<= result .<= 1.0)

    # Test with school closures
    school_closures = [(10.0, 15.0)]
    result = calc_labour_avail(
        df, n_workers, n_adults, n_school;
        times_school_closures = school_closures
    )
    @test isa(result, Matrix{Float64})
    @test all(0.0 .<= result .<= 1.0)

    # Test with both economic and school closures
    result = calc_labour_avail(
        df, n_workers, n_adults, n_school;
        times_econ_closures = econ_closures,
        times_school_closures = school_closures
    )
    @test isa(result, Matrix{Float64})
    @test all(0.0 .<= result .<= 1.0)

    # Test with no closures (should match default behaviour)
    result_no_closures = calc_labour_avail(
        df, n_workers, n_adults, n_school;
        times_econ_closures = nothing,
        times_school_closures = nothing
    )
    @test isa(result_no_closures, Matrix{Float64})
end

@testset "Labour availability errors" begin
    # Input validation tests
    # Load daedalus data
    # Test zero epidemic scenario
    df_zero = DataFrame(
        (time = t, compartment = comp, age_group = age) for
    t in 0:1 for comp in ["a", "b"] for age in ["working", "non-working"])
    df_zero.value .= 0.0
    transform!(
        df_zero, [:age_group] => ByRow((age) -> age == "working" ? "sector_01" :
                                                "sector_00") => :econ_sector
    )

    n_workers = [1000.0]
    scaling_dummy = Dict("a" => [1.0], "b" => [0.27])

    n_adults = sum(n_workers)
    n_school = 500.0
    n_sectors = length(unique(df_zero.econ_sector)) - 1 # do not count non-working

    # Negative n_adults
    @test_throws ArgumentError("n_adults must be >= 1.0, got -1000.0") calc_labour_avail(
        df_zero, n_workers, -1000.0, n_school
    )

    # Negative n_school
    @test_throws ArgumentError("n_school must be >= 0.0, got -100.0") calc_labour_avail(
        df_zero, n_workers, n_adults, -100.0
    )

    # Negative n_workers (scalar)
    @test_throws ArgumentError("n_workers[1] must be >= 1.0, got -100.0") calc_labour_avail(
        df_zero, [-100.0], n_adults, n_school
    )

    # Negative n_workers (vector element)
    bad_nw_vec = [-1.0; fill(10000.0, n_sectors - 1)]
    @test_throws ArgumentError("n_workers[1] must be >= 1.0, got -1.0") calc_labour_avail(
        df_zero, bad_nw_vec, n_adults, n_school
    )

    # n_workers vector length mismatch
    wrong_length_nw = fill(1000.0, n_sectors + 1)
    @test_throws ArgumentError("n_workers vector length must equal n_sectors ($n_sectors), got $(length(wrong_length_nw))") calc_labour_avail(
        df_zero, wrong_length_nw, n_adults, n_school, age_group_working = ["working"]
    )

    # scaling_wfh outside [0, 1] (too small)
    @test_throws ArgumentError("scaling_wfh must be in [0.0, 1.0], got -0.1") calc_labour_avail(
        df_zero, n_workers, n_adults, n_school;
        scaling_affected = scaling_dummy, scaling_wfh = -0.1,
        age_group_working = ["working"]
    )

    # scaling_wfh outside [0, 1] (too large)
    @test_throws ArgumentError("scaling_wfh must be in [0.0, 1.0], got 1.5") calc_labour_avail(
        df_zero, n_workers, n_adults, n_school; scaling_affected = scaling_dummy, scaling_wfh = 1.5,
        age_group_working = ["working"]
    )

    # scaling_care vector with invalid values
    bad_care_vec = [1.5]  # 1.5 is out of range
    @test_throws ArgumentError("scaling_care[1] must be in [0.0, 1.0], got 1.5") calc_labour_avail(
        df_zero, n_workers, n_adults, n_school;
        scaling_affected = scaling_dummy, scaling_care = bad_care_vec,
        age_group_working = ["working"]
    )

    # scaling_furl vector length mismatch
    wrong_furl_vec = fill(0.3, n_sectors + 1)
    @test_throws ArgumentError("scaling_furl vector length must equal n_sectors ($n_sectors), got $(length(wrong_furl_vec))") calc_labour_avail(
        df_zero, n_workers, n_adults, n_school;
        scaling_affected = scaling_dummy, scaling_furl = wrong_furl_vec,
        age_group_working = ["working"]
    )

    # scaling_affected with out-of-range values
    bad_scaling = default_labour_scaling(n_sectors)
    bad_scaling["infect_symp"][1] = 1.5  # Out of range
    @test_throws ArgumentError("scaling_affected[infect_symp][1] must be in [0.0, 1.0], got 1.5") calc_labour_avail(
        df_zero, n_workers, n_adults, n_school; scaling_affected = bad_scaling,
        age_group_working = ["working"]
    )
end

@testset "EpiHelpers.calc_consumption_avail" begin
    phi = repeat([0.01], 4)

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
    result = calc_consumption_avail(df_zero, phi)

    @test isa(result, Matrix{Float64})
    @test length(result) == length(phi)
    @test all(result .≈ 1.0)

    # non zero deaths
    df_spike = make_deaths_df([0.0, 0.0, 1.0, 1.0, 1.0])
    result = calc_consumption_avail(df_spike, phi)

    # TODO: check tests
    @test all(result .< 1.0)

    # Zero phi → no avoidance, all availability 1.0
    df_any = make_deaths_df([0.0, 1.0, 2.0, 3.0])
    result_zero_phi = calc_consumption_avail(df_any, 0.0)
    @test all(result_zero_phi .≈ 1.0)

    # Large phi → strong avoidance
    result_small_phi = calc_consumption_avail(df_any, 0.01)
    result_large_phi = calc_consumption_avail(df_any, 1.0)

    @test all(result_large_phi .< result_small_phi)

    # Custom compartment name via comp_deaths keyword
    df_custom = make_deaths_df([0.0, 2.0, 2.0], "sector_a", "mortality")
    result_custom = calc_consumption_avail(
        df_custom, phi; comp_deaths = "mortality")
    @test isa(result_custom, Matrix)
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
