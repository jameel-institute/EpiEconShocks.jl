
using DataFrames
using LinearAlgebra

function calc_hca_cost()

    # lt cost using HCA
    # assume total affectec individuals in group j and sector k
    n_age = 4
    n_sectors = 10
    v = ones(n_age, n_sectors)

    # assume p(disability) for each age group
    # uniform in this example
    p_disab = collect(2:2:8) ./ 100.0

    # assume proportional reduction in labour productivity
    p_lab_redn = p_disab .* 2.0

    # assume a matrix of time to retirement
    t_ret = copy(v) .* [30, 20, 10, 5]

    # assume a probability of employment that varies by age
    p_emp = 1.0 .- (1.0 ./ t_ret)

    # assume an an annual wage that is uniform over time, varying over age and sector
    wage = v .* collect(0.5:0.5:Float64(n_sectors / 2))'
    for i in 2:size(wage)[1]
        wage[i, :] .+= wage[i - 1, :]
    end

    ## calc prop pop disabled
    pop_disab = v .* p_disab

    # current annual morbidity related loss
    vtw = wage .* pop_disab .* p_emp .* p_lab_redn

    # discount rate
    r = 0.01

    # the discounting factor is the sum of a geometric series x0 + x1 + ... xT

    function get_discount_sum(times::Matrix{Float64})::Matrix{Float64}
        ((1.0 + r) / r) .* (1.0 .- (1.0 + r) .^ (-(times .+ 1.0)))
    end

    discount_sum = get_discount_sum(t_ret)

    pres_value = vtw .* discount_sum

    # discounting and present value for non-working children
    # assume 4 age groups entering N_j years from the present
    t_entry = copy(v) .* [1, 5, 10, 15]

    discount_sum_kids = get_discount_sum(t_ret + t_entry) - get_discount_sum(t_entry)
end
