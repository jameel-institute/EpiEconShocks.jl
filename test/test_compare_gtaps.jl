@testset "compare_gtaps" begin
    @test_skip begin
        # This test set verifies the compare_gtaps function, which compares baseline
        # and shocked GTAP models to extract economic outcome measures.

        # Get an example model to work with
        baseline_model = EpiEconShocks.Example.get_example_model()

        # Create a simple shock to apply
        labour_shock = ParameterShock("qe", ["skilled labor", "unskilled labor"], 0.95)

        # Apply shock to get a modified model
        shocked_model = EpiEconShocks.shock_gtap(baseline_model, [labour_shock])

        # Compare the two models
        outcomes = EpiEconShocks.compare_gtaps(baseline_model, shocked_model)

        # Test that outcomes is a named tuple with the expected fields
        @test haskey(outcomes, :y)
        @test haskey(outcomes, :ev)
        @test haskey(outcomes, :delta_gdp)

        # Test that all outputs are NamedArray objects
        @test isa(outcomes.y, NamedArray)
        @test isa(outcomes.ev, NamedArray)
        @test isa(outcomes.delta_gdp, NamedArray)

        # Test dimensions: should have one column and as many rows as regions
        n_regions = length(baseline_model.sets["reg"])
        @test size(outcomes.y, 1) == n_regions
        @test size(outcomes.ev, 1) == n_regions
        @test size(outcomes.delta_gdp, 1) == n_regions
        @test size(outcomes.y, 2) == 1
        @test size(outcomes.ev, 2) == 1
        @test size(outcomes.delta_gdp, 2) == 1

        # Test that region names are preserved in the NamedArray
        regions = baseline_model.sets["reg"]
        @test names(outcomes.y)[1] == regions
        @test names(outcomes.ev)[1] == regions
        @test names(outcomes.delta_gdp)[1] == regions

        # Test that results are numeric
        @test eltype(outcomes.y) <: Number
        @test eltype(outcomes.ev) <: Number
        @test eltype(outcomes.delta_gdp) <: Number

        # Test that delta_gdp values are finite (not NaN or Inf)
        @test all(isfinite, outcomes.delta_gdp)

        # Test that y (income/GDP) values are non-negative in baseline comparison
        # (income should be positive in both models)
        @test all(outcomes.y .>= 0)

        # Test that multiple shocks can be applied and compared
        consumption_shock = ParameterShock("qpa", "svces", 0.90)
        multi_shocked_model = EpiEconShocks.shock_gtap(baseline_model, [
            labour_shock, consumption_shock])
        multi_outcomes = EpiEconShocks.compare_gtaps(baseline_model, multi_shocked_model)

        @test haskey(multi_outcomes, :y)
        @test haskey(multi_outcomes, :ev)
        @test haskey(multi_outcomes, :delta_gdp)
        @test size(multi_outcomes.delta_gdp, 1) == n_regions

        # Test that no shock (applying identity shocks) results in minimal changes
        # Identity shock: multiply by 1.0 (no change)
        identity_shock = ParameterShock("qe", ["skilled labor", "unskilled labor"], 1.0)
        identity_shocked = EpiEconShocks.shock_gtap(baseline_model, [identity_shock])
        identity_outcomes = EpiEconShocks.compare_gtaps(baseline_model, identity_shocked)

        # With no actual shock, delta_gdp should be very close to zero (within numerical tolerance)
        @test all(abs.(identity_outcomes.delta_gdp) .< 1e-4)

        # Test that the function is deterministic: comparing the same models twice gives the same result
        outcomes2 = EpiEconShocks.compare_gtaps(baseline_model, shocked_model)
        @test outcomes.delta_gdp ≈ outcomes2.delta_gdp
        @test outcomes.ev ≈ outcomes2.ev
        @test outcomes.y ≈ outcomes2.y

        # Test that comparing a model with itself yields zero GDP change
        self_comparison = EpiEconShocks.compare_gtaps(baseline_model, baseline_model)
        @test all(self_comparison.delta_gdp .≈ 0.0)
    end
end
