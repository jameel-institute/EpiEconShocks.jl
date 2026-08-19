@testset "LtCosts.calc_hca_cost basic functionality" begin
    # brute-force reference for the geometric discounting series used
    # internally, to independently validate the closed-form calculation
    function manual_discount_sum(t::Real, r::Real)
        sum((1.0 / (1.0 + r))^i for i in 0:Int(round(t)))
    end

    n_age, n_sectors = 2, 3
    n_recovered = [10.0 20.0 30.0; 5.0 15.0 25.0]
    n_dead = [1.0 2.0 3.0; 0.5 1.5 2.5]
    p_disab = [0.1, 0.2]
    p_lab_redn = [0.5, 0.3]
    t_ret = repeat([20.0, 10.0], 1, n_sectors)
    t_entry = zeros(n_age, n_sectors) # all age groups already working
    wage = fill(100.0, n_age, n_sectors)
    p_emp = 0.8
    r = 0.03

    result = calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry,
        wage, p_emp; discount_rate = r
    )
    val_no_discounting = calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry,
        wage, p_emp; discount_rate = 0.0
    )

    @test isa(result, Matrix{Float64})
    @test size(result) == (n_age, n_sectors)
    @test all(isfinite.(result))
    @test all(result .>= 0.0)
    @test all(result .<= val_no_discounting)

    # manual check for correctness
    discount = manual_discount_sum.(t_ret, r)
    pop_disab = n_recovered .* p_disab
    lt = wage .* p_emp .* pop_disab .* p_lab_redn
    expected = lt .* discount + wage .* p_emp .* n_dead .* discount
    @test result ≈ expected
end

@testset "LtCosts.calc_hca_cost proportional loss when wage = nothing" begin
    n_age, n_sectors = 2, 2
    n_recovered = fill(10.0, n_age, n_sectors)
    n_dead = fill(1.0, n_age, n_sectors)
    p_disab = [0.1, 0.2]
    p_lab_redn = [0.4, 0.6]
    t_ret = fill(15.0, n_age, n_sectors)
    t_entry = zeros(n_age, n_sectors)

    result_prop = calc_hca_cost(n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry)
    result_wage_one = calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry, ones(n_age, n_sectors)
    )

    @test result_prop ≈ result_wage_one
end

@testset "LtCosts.calc_hca_cost with vector p_emp" begin
    n_age, n_sectors = 2, 2
    n_recovered = fill(10.0, n_age, n_sectors)
    n_dead = fill(1.0, n_age, n_sectors)
    p_disab = [0.1, 0.2]
    p_lab_redn = [0.4, 0.6]
    t_ret = fill(15.0, n_age, n_sectors)
    t_entry = zeros(n_age, n_sectors)
    p_emp_scalar = 0.8
    p_emp_vec = fill(p_emp_scalar, n_age)

    result_scalar = calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry, nothing, p_emp_scalar
    )
    result_vec = calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry, nothing, p_emp_vec
    )

    @test isa(result_vec, Matrix{Float64})
    @test size(result_vec) == (n_age, n_sectors)
    @test result_vec ≈ result_scalar
end

@testset "LtCosts.calc_hca_cost with matrix (sector-varying) parameters" begin
    n_age, n_sectors = 2, 3
    n_recovered = [10.0 20.0 30.0; 5.0 15.0 25.0]
    n_dead = [1.0 2.0 3.0; 0.5 1.5 2.5]
    p_disab_vec = [0.1, 0.2]
    p_lab_redn_vec = [0.5, 0.3]
    t_ret = repeat([20.0, 10.0], 1, n_sectors)
    t_entry = zeros(n_age, n_sectors)
    p_emp_vec = [0.8, 0.7]

    result_vec = calc_hca_cost(
        n_recovered, n_dead, p_disab_vec, p_lab_redn_vec, t_ret, t_entry,
        nothing, p_emp_vec
    )

    # a matrix built by repeating a vector across sectors carries no
    # additional information, so results must match exactly regardless of
    # which parameters are passed as matrices
    result_mat = calc_hca_cost(
        n_recovered, n_dead, repeat(p_disab_vec, 1, n_sectors),
        repeat(p_lab_redn_vec, 1, n_sectors), t_ret, t_entry,
        nothing, repeat(p_emp_vec, 1, n_sectors)
    )
    @test result_mat ≈ result_vec

    # sector-only variation in p_disab propagates to the output
    p_disab_sector = [0.1 0.2 0.3; 0.1 0.2 0.3]
    result_sector = calc_hca_cost(
        fill(10.0, 1, 3), zeros(1, 3), [0.1 0.2 0.3], [0.5],
        fill(20.0, 1, 3), zeros(1, 3)
    )

    @test result_sector[1, 1] < result_sector[1, 2] < result_sector[1, 3]
end

@testset "LtCosts.calc_hca_cost with scalar p_disab and p_lab_redn" begin
    n_age, n_sectors = 2, 3
    n_recovered = [10.0 20.0 30.0; 5.0 15.0 25.0]
    n_dead = [1.0 2.0 3.0; 0.5 1.5 2.5]
    t_ret = repeat([20.0, 10.0], 1, n_sectors)
    t_entry = zeros(n_age, n_sectors)
    p_disab_scalar = 0.15
    p_lab_redn_scalar = 0.4

    result_scalar = calc_hca_cost(
        n_recovered, n_dead, p_disab_scalar, p_lab_redn_scalar, t_ret, t_entry
    )
    result_mat = calc_hca_cost(
        n_recovered, n_dead, fill(p_disab_scalar, n_age, n_sectors),
        fill(p_lab_redn_scalar, n_age, n_sectors), t_ret, t_entry
    )

    @test isa(result_scalar, Matrix{Float64})
    @test size(result_scalar) == (n_age, n_sectors)
    @test result_scalar ≈ result_mat
end

@testset "LtCosts.calc_hca_cost input validation" begin
    n_age, n_sectors = 2, 2
    n_recovered = fill(10.0, n_age, n_sectors)
    n_dead = fill(1.0, n_age, n_sectors)
    p_disab = [0.1, 0.2]
    p_lab_redn = [0.4, 0.6]
    t_ret = fill(15.0, n_age, n_sectors)
    t_entry = zeros(n_age, n_sectors)

    # n_dead wrong size
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, fill(1.0, n_age + 1, n_sectors), p_disab, p_lab_redn, t_ret, t_entry
    )

    # t_ret wrong size
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, fill(15.0, n_age, n_sectors + 1), t_entry
    )

    # t_entry wrong size
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, fill(0.0, n_age + 1, n_sectors)
    )

    # p_disab wrong length
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, [0.1], p_lab_redn, t_ret, t_entry
    )

    # p_disab wrong matrix shape
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, fill(0.1, n_age, n_sectors + 1), p_lab_redn, t_ret, t_entry
    )

    # p_lab_redn wrong length
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, [0.4], t_ret, t_entry
    )

    # wage wrong size
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry,
        fill(100.0, n_age, n_sectors + 1)
    )

    # p_emp vector wrong length
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry, nothing, [0.8]
    )

    # p_disab value out of [0.0, 1.0]
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, [0.1, 1.1], p_lab_redn, t_ret, t_entry
    )

    # t_ret negative value
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, fill(-1.0, n_age, n_sectors), t_entry
    )

    # t_entry non-finite value
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, fill(Inf, n_age, n_sectors)
    )

    # discount_rate NaN
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry;
        discount_rate = NaN
    )

    # discount_rate Inf
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry;
        discount_rate = Inf
    )

    # discount_rate exactly -1.0
    @test_throws ArgumentError calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry;
        discount_rate = -1.0
    )

    # discount_rate valid negative value in (-1.0, 0.0)
    result = calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry;
        discount_rate = -0.5
    )
    @test isa(result, Matrix{Float64})
    @test all(isfinite.(result))
end
