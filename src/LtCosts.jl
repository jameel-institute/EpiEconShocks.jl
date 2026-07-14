
module LtCosts

export calc_hca_cost

using DataFrames
using Distributions
using LinearAlgebra
using Random

"""
    get_discount_sum(times::Matrix{<:Real}, r::Float64)

Helper function to get the sum of a geometric series where
    ``x = \frac{1}{1+r}``; used to calculate the discounting multiplier on
    future wages.
"""
function get_discount_sum(times::Matrix{<:Real}, r::Float64)
    ((1.0 + r) / r) .* (1.0 .- (1.0 + r) .^ (-(times .+ 1.0)))
end

"""
    calc_hca_cost(n_recovered, n_dead, p_disab, p_lab_redn, t_ret, t_entry,
                  wage = nothing, p_emp = 0.8; discount_rate = 0.01)

Calculate the present-value loss in lifetime wages attributable to long-term,
infection-related disability and death, using the Human Capital Approach
(HCA).

Current workers and future workers (e.g. children not yet in the labour
market) are combined into a single set of age groups: each row of
`n_recovered` and `n_dead` represents one age group, and whether that age
group is already working or will enter the labour market later is encoded
per-row in `t_entry` (`0.0` for age groups already working) and `t_ret`.
The disability loss reflects a permanent reduction in labour productivity
for survivors (eqn 22), while the death loss reflects the full forgone
future wage. Both are discounted from the present over the working period
running from labour market entry (`t_entry`) to retirement
(`t_entry + t_ret`).

# Arguments
- `n_recovered::Matrix{Float64}`: Number of recovered by age group and
    economic sector, of size `(n_age, n_sectors)`. Age groups may combine
    both current and future workers (see `t_entry`).
- `n_dead::Matrix{Float64}`: Number of deaths by age group and economic
    sector, of size `(n_age, n_sectors)`.
- `p_disab::Vector{Float64}`: Probability of long-term disability among
    recovered, by age group (length `n_age`).
- `p_lab_redn::Vector{Float64}`: Proportional reduction in labour
    productivity for disabled individuals, by age group (length `n_age`).
- `t_ret::Matrix{Float64}`: Years of working life remaining after labour
    market entry (i.e. years until retirement, counted from entry), by age
    group and economic sector, of size `(n_age, n_sectors)`.
- `t_entry::Matrix{Float64}`: Years until labour market entry, by age group
    and economic sector, of size `(n_age, n_sectors)`; `0.0` for age groups
    already working.
- `wage::Union{Matrix{Float64}, Nothing}`: Annual wage, by age group and
    economic sector, of size `(n_age, n_sectors)`. If `nothing` (default),
    losses are computed as a proportion of wage (`wage` is treated as
    `1.0`) rather than in currency units.
- `p_emp::Union{Float64, Vector{Float64}}`: Probability of employment given
    participation in the labour force. May be a single value applied to all
    age groups or a vector by age group (length `n_age`) (default: `0.8`).
- `discount_rate::Real`: Annual discount rate applied to future earnings
    (default: `0.01`).

# Returns
- `Matrix{Float64}`: Present-value wage loss (or proportional loss, if
    `wage` is `nothing`) from disability and death combined, by age group
    and economic sector, of size `(n_age, n_sectors)`.

# Raises
- `ArgumentError`: if `n_dead`, `t_ret`, `t_entry`, or `wage` (when
    provided) do not share the size `(n_age, n_sectors)` of `n_recovered`;
    if `p_disab` or `p_lab_redn` do not have length `n_age`; or if `p_emp`
    is a vector without length `n_age`.
"""
function calc_hca_cost(
        n_recovered::Matrix{Float64},
        n_dead::Matrix{Float64},
        p_disab::Vector{Float64},
        p_lab_redn::Vector{Float64},
        t_ret::Matrix{Float64},
        t_entry::Matrix{Float64},
        wage::Union{Matrix{Float64}, Nothing} = nothing,
        p_emp::Union{Float64, Vector{Float64}} = 0.8;
        discount_rate::Real = 0.01
)
    n_age, n_sectors = size(n_recovered)

    for (name, m) in ((:n_dead, n_dead), (:t_ret, t_ret), (:t_entry, t_entry))
        if size(m) != (n_age, n_sectors)
            throw(ArgumentError(
                "`$name` must have size ($n_age, $n_sectors), got $(size(m))"
            ))
        end
    end

    for (name, v) in ((:p_disab, p_disab), (:p_lab_redn, p_lab_redn))
        if length(v) != n_age
            throw(ArgumentError("`$name` must have length $n_age, got $(length(v))"))
        end
    end

    if !isnothing(wage) && size(wage) != (n_age, n_sectors)
        throw(ArgumentError(
            "`wage` must have size ($n_age, $n_sectors), got $(size(wage))"
        ))
    end

    if p_emp isa AbstractVector && length(p_emp) != n_age
        throw(ArgumentError(
            "`p_emp` must have length $n_age, got $(length(p_emp))"
        ))
    end

    # handle proportional calculation
    wage = isnothing(wage) ? 1.0 : wage

    ## calc prop pop disabled and dead
    pop_disab = n_recovered .* p_disab

    # current annual morbidity related loss
    lt = wage .* p_emp .* pop_disab .* p_lab_redn # eqn 22

    # apply for all age groups
    discount = get_discount_sum(t_ret + t_entry, discount_rate) -
               get_discount_sum(t_entry, discount_rate)

    loss_disab = lt .* discount
    loss_death = wage .* n_dead .* discount

    return loss_disab + loss_death
end

end
