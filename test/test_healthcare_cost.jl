@testset "LtCosts.calc_healthcare_cost basic functionality" begin
    # brute-force reference for the geometric discounting series used
    # internally, to independently validate the closed-form calculation
    function manual_discount_sum(t::Real, r::Real)
        sum((1.0 / (1.0 + r))^i for i in 0:Int(round(t)))
    end

    n_age, n_sectors = 2, 3
    n_recovered = [10.0 20.0 30.0; 5.0 15.0 25.0]
    p_disab = [0.1, 0.2]
    t_life = [30.0, 15.0]
    cost_care = [1000.0, 2000.0]
    r = 0.03

    result = calc_healthcare_cost(
        n_recovered, p_disab, t_life, cost_care; discount_rate = r
    )
    val_no_discounting = calc_healthcare_cost(
        n_recovered, p_disab, t_life, cost_care; discount_rate = 1e-12
    )

    @test isa(result, Matrix{Float64})
    @test size(result) == (n_age, n_sectors)
    @test all(isfinite.(result))
    @test all(result .>= 0.0)
    @test all(result .< val_no_discounting)

    # manual check for correctness
    discount = manual_discount_sum.(t_life, r)
    pop_disab = n_recovered .* p_disab
    expected = pop_disab .* cost_care .* discount
    @test result ≈ expected
end

@testset "LtCosts.calc_healthcare_cost zero discount rate" begin
    n_age, n_sectors = 2, 2
    n_recovered = fill(10.0, n_age, n_sectors)
    p_disab = [0.1, 0.2]
    t_life = [10.0, 5.0]
    cost_care = 500.0

    result = calc_healthcare_cost(
        n_recovered, p_disab, t_life, cost_care; discount_rate = 0.0
    )

    pop_disab = n_recovered .* p_disab
    expected = pop_disab .* cost_care .* (t_life .+ 1.0)
    @test result ≈ expected
end

@testset "LtCosts.calc_healthcare_cost with age-varying parameters" begin
    n_age, n_sectors = 2, 3
    n_recovered = [10.0 20.0 30.0; 5.0 15.0 25.0]
    p_disab_vec = [0.1, 0.2]
    t_life = [30.0, 15.0]

    result_scalar_cost = calc_healthcare_cost(
        n_recovered, p_disab_vec, t_life, 1000.0
    )

    # a vector built by repeating the scalar carries no additional
    # information
    result_vec_cost = calc_healthcare_cost(
        n_recovered, p_disab_vec, t_life, fill(1000.0, n_age)
    )
    @test result_vec_cost ≈ result_scalar_cost

    # genuine age variation in cost_care propagates to the output
    result_age = calc_healthcare_cost(
        fill(10.0, 2, 1), [0.2, 0.2], [10.0, 10.0], [500.0, 1500.0]
    )
    @test result_age[2, 1] ≈ result_age[1, 1] * 3
end

@testset "LtCosts.calc_healthcare_cost longer life horizon increases cost" begin
    n_recovered = [10.0;;]
    p_disab = [0.2]
    cost_care = [500.0]

    result_short = calc_healthcare_cost(n_recovered, p_disab, 1.0, cost_care)
    result_long = calc_healthcare_cost(n_recovered, p_disab, 20.0, cost_care)

    @test result_long[1, 1] > result_short[1, 1]
end

@testset "LtCosts.calc_healthcare_cost input validation" begin
    n_age, n_sectors = 2, 2
    n_recovered = fill(10.0, n_age, n_sectors)
    p_disab = [0.1, 0.2]
    t_life = fill(10.0, n_age)
    cost_care = fill(500.0, n_age)

    # p_disab wrong length
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, [0.1], t_life, cost_care
    )

    # p_disab value out of [0.0, 1.0]
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, [-0.1, 0.5], t_life, cost_care
    )

    # t_life wrong length
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, fill(10.0, n_age + 1), cost_care
    )

    # t_life negative value
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, fill(-1.0, n_age), cost_care
    )

    # t_life non-finite value
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, NaN, cost_care
    )

    # cost_care wrong length
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, fill(500.0, n_age + 1)
    )

    # cost_care scalar negative value
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, -500.0
    )

    # cost_care scalar NaN value
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, NaN
    )

    # cost_care scalar Inf value
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, Inf
    )

    # cost_care vector negative value
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, [-500.0, 500.0]
    )

    # cost_care vector NaN value
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, [500.0, NaN]
    )

    # cost_care vector Inf value
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, [500.0, Inf]
    )

    # discount_rate NaN
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, cost_care; discount_rate = NaN
    )

    # discount_rate Inf
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, cost_care; discount_rate = Inf
    )

    # discount_rate exactly -1.0
    @test_throws ArgumentError calc_healthcare_cost(
        n_recovered, p_disab, t_life, cost_care; discount_rate = -1.0
    )

    # discount_rate valid negative value in (-1.0, 0.0)
    result = calc_healthcare_cost(
        n_recovered, p_disab, t_life, cost_care; discount_rate = -0.5
    )
    @test isa(result, Matrix{Float64})
    @test all(isfinite.(result))
end
