@testset "LtCosts.calc_fca_cost basic functionality" begin
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
    p_disab_replaced = [0.6, 0.4]
    t_replacement = [2.0, 1.0]
    wage = fill(100.0, n_age, n_sectors)
    p_emp = 0.8
    r = 0.03

    result = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, t_replacement,
        wage, p_emp; discount_rate = r
    )
    val_no_discounting = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, t_replacement,
        wage, p_emp; discount_rate = 1e-12
    )

    @test isa(result, Matrix{Float64})
    @test size(result) == (n_age, n_sectors)
    @test all(isfinite.(result))
    @test all(result .>= 0.0)
    @test all(result .< val_no_discounting)

    # manual check for correctness
    discount = manual_discount_sum.(t_replacement, r)
    pop_disab = n_recovered .* p_disab .* p_disab_replaced
    lt = wage .* p_emp .* pop_disab .* p_lab_redn
    expected = lt .* discount + wage .* p_emp .* n_dead .* discount
    @test result ≈ expected
end

@testset "LtCosts.calc_fca_cost proportional loss when wage = nothing" begin
    n_age, n_sectors = 2, 2
    n_recovered = fill(10.0, n_age, n_sectors)
    n_dead = fill(1.0, n_age, n_sectors)
    p_disab = [0.1, 0.2]
    p_lab_redn = [0.4, 0.6]
    p_disab_replaced = [0.5, 0.5]
    t_replacement = 0.5

    result_prop = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, t_replacement
    )
    result_wage_one = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, t_replacement,
        ones(n_age, n_sectors)
    )

    @test result_prop ≈ result_wage_one
end

@testset "LtCosts.calc_fca_cost with vector p_emp" begin
    n_age, n_sectors = 2, 2
    n_recovered = fill(10.0, n_age, n_sectors)
    n_dead = fill(1.0, n_age, n_sectors)
    p_disab = [0.1, 0.2]
    p_lab_redn = [0.4, 0.6]
    p_disab_replaced = [0.5, 0.5]
    t_replacement = 0.5
    p_emp_scalar = 0.8
    p_emp_vec = fill(p_emp_scalar, n_age)

    result_scalar = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, t_replacement,
        nothing, p_emp_scalar
    )
    result_vec = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, t_replacement,
        nothing, p_emp_vec
    )

    @test isa(result_vec, Matrix{Float64})
    @test size(result_vec) == (n_age, n_sectors)
    @test result_vec ≈ result_scalar
end

@testset "LtCosts.calc_fca_cost p_disab_replaced gates disability cost" begin
    n_recovered = [10.0;;]
    n_dead = [0.0;;] # isolate the disability term
    p_disab = [0.2]
    p_lab_redn = [0.5]
    t_replacement = [0.5]

    result_none_replaced = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, [0.0], t_replacement
    )
    result_all_replaced = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, [1.0], t_replacement
    )
    result_half_replaced = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, [0.5], t_replacement
    )

    @test result_none_replaced[1, 1] ≈ 0.0
    @test result_half_replaced[1, 1] ≈ result_all_replaced[1, 1] / 2
end

@testset "LtCosts.calc_fca_cost longer replacement time increases cost" begin
    n_recovered = [10.0;;]
    n_dead = [1.0;;]
    p_disab = [0.2]
    p_lab_redn = [0.5]
    p_disab_replaced = [0.5]

    result_short = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, 0.1
    )
    result_long = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, 2.0
    )

    @test result_long[1, 1] > result_short[1, 1]
end

@testset "LtCosts.calc_fca_cost matches calc_hca_cost under equivalent assumptions" begin
    # The FCA and HCA formulas coincide exactly when: there are no
    # non-working (future) age groups (t_entry = 0, so the HCA discount sum
    # is not truncated at the entry year); the FCA replacement time equals
    # the HCA remaining working life (t_replacement = t_ret, per age group);
    # and every disabled worker is assumed to be replaced
    # (p_disab_replaced = 1.0), so the FCA's disabled population reduces to
    # the HCA's.
    n_age, n_sectors = 2, 3
    n_recovered = [10.0 20.0 30.0; 5.0 15.0 25.0]
    n_dead = [1.0 2.0 3.0; 0.5 1.5 2.5]
    p_disab = [0.1, 0.2]
    p_lab_redn = [0.5, 0.3]
    t_ret_vec = [20.0, 10.0]
    t_ret = repeat(t_ret_vec, 1, n_sectors)
    t_entry = zeros(n_age, n_sectors) # no non-working (future) age groups
    p_disab_replaced = ones(n_age) # every disabled worker is replaced
    wage = fill(100.0, n_age, n_sectors)
    p_emp = 1.0
    r = 0.03

    result_hca = calc_hca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry,
        wage, p_emp; discount_rate = r
    )
    result_fca = calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, t_ret_vec,
        wage, p_emp; discount_rate = r
    )

    @test result_fca ≈ result_hca
end

@testset "LtCosts.calc_fca_cost with matrix (sector-varying) parameters" begin
    n_age, n_sectors = 2, 3
    n_recovered = [10.0 20.0 30.0; 5.0 15.0 25.0]
    n_dead = [1.0 2.0 3.0; 0.5 1.5 2.5]
    p_disab_vec = [0.1, 0.2]
    p_lab_redn_vec = [0.5, 0.3]
    p_disab_replaced_vec = [0.6, 0.4]
    t_replacement = [2.0, 1.0]
    p_emp_vec = [0.8, 0.7]

    result_vec = calc_fca_cost(
        n_recovered, n_dead, p_disab_vec, p_lab_redn_vec, p_disab_replaced_vec,
        t_replacement, nothing, p_emp_vec
    )

    # a matrix built by repeating a vector across sectors carries no
    # additional information; mixing vector and matrix arguments must also
    # compose correctly via broadcasting
    result_mixed = calc_fca_cost(
        n_recovered, n_dead, repeat(p_disab_vec, 1, n_sectors), p_lab_redn_vec,
        repeat(p_disab_replaced_vec, 1, n_sectors), t_replacement,
        nothing, p_emp_vec
    )
    @test result_mixed ≈ result_vec

    # genuine sector variation in p_disab_replaced propagates to the output
    result_sector = calc_fca_cost(
        fill(10.0, 1, 3), zeros(1, 3), [0.2], [0.5], [0.0 0.5 1.0], [0.5]
    )
    @test result_sector[1, 1] ≈ 0.0
    @test result_sector[1, 2] ≈ result_sector[1, 3] / 2
end

@testset "LtCosts.calc_fca_cost with scalar p_disab and p_lab_redn" begin
    n_age, n_sectors = 2, 3
    n_recovered = [10.0 20.0 30.0; 5.0 15.0 25.0]
    n_dead = [1.0 2.0 3.0; 0.5 1.5 2.5]
    p_disab_replaced = [0.6, 0.4]
    t_replacement = [2.0, 1.0]
    p_disab_scalar = 0.15
    p_lab_redn_scalar = 0.4

    result_scalar = calc_fca_cost(
        n_recovered, n_dead, p_disab_scalar, p_lab_redn_scalar,
        p_disab_replaced, t_replacement
    )
    result_mat = calc_fca_cost(
        n_recovered, n_dead, fill(p_disab_scalar, n_age, n_sectors),
        fill(p_lab_redn_scalar, n_age, n_sectors), p_disab_replaced, t_replacement
    )

    @test isa(result_scalar, Matrix{Float64})
    @test size(result_scalar) == (n_age, n_sectors)
    @test result_scalar ≈ result_mat
end

@testset "LtCosts.calc_fca_cost input validation" begin
    n_age, n_sectors = 2, 2
    n_recovered = fill(10.0, n_age, n_sectors)
    n_dead = fill(1.0, n_age, n_sectors)
    p_disab = [0.1, 0.2]
    p_lab_redn = [0.4, 0.6]
    p_disab_replaced = [0.5, 0.5]
    t_replacement = fill(0.5, n_age)

    # n_dead wrong size
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, fill(1.0, n_age + 1, n_sectors), p_disab, p_lab_redn,
        p_disab_replaced, t_replacement
    )

    # t_replacement wrong length
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced,
        fill(0.5, n_age + 1)
    )

    # p_disab wrong length
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, [0.1], p_lab_redn, p_disab_replaced, t_replacement
    )

    # p_disab wrong matrix shape
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, fill(0.1, n_age, n_sectors + 1), p_lab_redn,
        p_disab_replaced, t_replacement
    )

    # p_lab_redn wrong length
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, p_disab, [0.4], p_disab_replaced, t_replacement
    )

    # p_disab_replaced wrong length
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, [0.5], t_replacement
    )

    # wage wrong size
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, t_replacement,
        fill(100.0, n_age, n_sectors + 1)
    )

    # p_emp vector wrong length
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, t_replacement,
        nothing, [0.8]
    )

    # p_disab_replaced value out of [0.0, 1.0]
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, [-0.1, 0.5], t_replacement
    )

    # t_replacement negative value
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, fill(-0.5, n_age)
    )

    # t_replacement non-finite value
    @test_throws ArgumentError calc_fca_cost(
        n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced, NaN
    )
end
