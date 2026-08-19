
module LtCosts

export calc_hca_cost, calc_fca_cost, calc_healthcare_cost

using DataFrames
using Distributions
using LinearAlgebra
using Random

"""
    get_discount_sum(times::Real, r::Float64)::Float64

Sum of the discounted geometric series
``\\sum_{i=0}^{\\text{times}} \\left(\\frac{1}{1+r}\\right)^i``, used to
calculate the discounting multiplier applied to a constant annual wage (or
wage loss) accruing over `times + 1` years, from the present (`i = 0`,
undiscounted) out to `times` years in the future. `times` need not be an
integer.

The sum is expressed as ``\\frac{1 + r}{r} (1 - (1 + r))^{-(t + 1)}`` following
the formula for the sum of a finite geometric series.

# Arguments
- `times::Real`: Upper index of the summation.
- `r::Float64`: Discount rate. When `r` is approximately `0.0` the undiscounted
    value `times + 1.0` is returned. Must be finite and greater than `-1.0`.

# Returns
- `Float64`: The discounted sum.

# Raises
- `ArgumentError`: if `r` is not finite, or is not greater than `-1.0`.
"""
function get_discount_sum(times::Real, r::Float64)::Float64
    if !isfinite(r) || r <= -1.0
        throw(ArgumentError("`discount_rate` must be finite and greater than -1.0"))
    end

    if r ≈ 0.0
        return times + 1.0
    else
        return ((1.0 + r) / r) * (1.0 - (1.0 + r) ^ (-(times + 1.0)))
    end
end

"""
    _validate_age_sector_param(name, v, n_age, n_sectors)

Validate that `v` is either a scalar, a `Vector` of length `n_age` (variation
by age only), or a `Matrix` of size `(n_age, n_sectors)` (variation by age and
economic sector), and that all of its values lie in `[0.0, 1.0]`. Throws
`ArgumentError` naming `name` on a size mismatch or an out-of-range value.
"""
function _validate_age_sector_param(
        name::Symbol,
        v::Union{Float64, AbstractVector{Float64}, AbstractMatrix{Float64}},
        n_age::Int, n_sectors::Int
)
    if v isa AbstractVector && length(v) != n_age
        throw(ArgumentError("`$name` must have length $n_age, got $(length(v))"))
    elseif v isa AbstractMatrix && size(v) != (n_age, n_sectors)
        throw(ArgumentError(
            "`$name` must have size ($n_age, $n_sectors) when a matrix, or " *
            "length $n_age when a vector, got size $(size(v))"
        ))
    end

    if !all(x -> 0.0 <= x <= 1.0, v)
        throw(ArgumentError("`$name` must have all values in [0.0, 1.0]"))
    end
end

"""
    _validate_time(name, v)

Validate that all values in `v` (a scalar, `Vector`, or `Matrix`) are
non-negative and finite (not `Inf`, `-Inf`, or `NaN`). Throws `ArgumentError`
naming `name` otherwise.
"""
function _validate_time(
        name::Symbol,
        v::Union{Float64, AbstractVector{Float64}, AbstractMatrix{Float64}}
)
    if !all(x -> isfinite(x) && x >= 0.0, v)
        throw(ArgumentError("`$name` must be non-negative and finite"))
    end
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
for survivors, while the death loss reflects the full forgone
future wage. Both are discounted from the present over a working period of
`t_ret + 1` years — the entry year itself, plus `t_ret` further years —
running from labour market entry (year `t_entry`) to retirement (year
`t_entry + t_ret`), inclusive of both endpoints.

# Arguments
- `n_recovered::Matrix{Float64}`: Number of recovered by age group and
    economic sector, of size `(n_age, n_sectors)`. Age groups may combine
    both current and future workers (see `t_entry`).
- `n_dead::Matrix{Float64}`: Number of deaths by age group and economic
    sector, of size `(n_age, n_sectors)`.
- `p_disab::Union{Float64, Vector{Float64}, Matrix{Float64}}`: Probability
    of long-term disability among recovered. A scalar applies the same
    probability to every age group and sector; alternatively a `Vector` by
    age group (length `n_age`), or a `Matrix` by age group and economic
    sector, of size `(n_age, n_sectors)`, for sector-specific variation.
- `p_lab_redn::Union{Float64, Vector{Float64}, Matrix{Float64}}`:
    Proportional reduction in labour productivity for disabled individuals.
    A scalar applies the same reduction to every age group and sector;
    alternatively a `Vector` by age group (length `n_age`), or a `Matrix` by
    age group and economic sector, of size `(n_age, n_sectors)`, for
    sector-specific variation. Note that this is the proportional
    reduction, and not a scaling factor. To represent a productivity of
    80%, pass 0.2 for a reduction of 20%.
- `t_ret::Matrix{Float64}`: Number of years, after labour market entry, over
    which lost wages accrue; the discounted window spans `t_ret + 1` years
    in total (see above), by age group and economic sector, of size
    `(n_age, n_sectors)`.
- `t_entry::Matrix{Float64}`: Years until labour market entry, by age group
    and economic sector, of size `(n_age, n_sectors)`; should be `0.0` for age
    groups already working.
- `wage::Union{Float64, Matrix{Float64}, Nothing}`: Annual wage, by age
    group and economic sector, of size `(n_age, n_sectors)`. A scalar
    applies the same wage to every age group and sector. If `nothing`
    (default), losses are computed as a proportion of the per-capita annual wage
    (`wage` is treated as `1.0`) rather than in currency units.
- `p_emp::Union{Float64, Vector{Float64}, Matrix{Float64}}`: Probability of
    employment given participation in the labour force. May be a single
    value applied to all age groups and sectors, a `Vector` by age group
    (length `n_age`), or a `Matrix` by age group and economic sector, of
    size `(n_age, n_sectors)` (default: `0.8`).
- `discount_rate::Float64`: Annual discount rate applied to future earnings
    (default: `0.01`). Must be finite and greater than `-1.0`.

# Returns
- `Matrix{Float64}`: Present-value wage loss (or proportional loss, if
    `wage` is `nothing`) from disability and death combined, by age group
    and economic sector, of size `(n_age, n_sectors)`.

# Raises
- `ArgumentError`: if `n_dead`, `t_ret`, `t_entry`, or `wage` (when
    provided) do not share the size `(n_age, n_sectors)` of `n_recovered`;
    if `p_disab`, `p_lab_redn`, or `p_emp` are a vector without length
    `n_age`, a matrix without size `(n_age, n_sectors)`, or contain a value
    outside `[0.0, 1.0]`; if `t_ret` or `t_entry` contain a negative or
    non-finite value; or if `discount_rate` is not finite or not greater
    than `-1.0`.
"""
function calc_hca_cost(
        n_recovered::Matrix{Float64},
        n_dead::Matrix{Float64},
        p_disab::Union{Float64, Vector{Float64}, Matrix{Float64}},
        p_lab_redn::Union{Float64, Vector{Float64}, Matrix{Float64}},
        t_ret::Matrix{Float64},
        t_entry::Matrix{Float64},
        wage::Union{Float64, Matrix{Float64}, Nothing} = nothing,
        p_emp::Union{Float64, Vector{Float64}, Matrix{Float64}} = 0.8;
        discount_rate::Float64 = 0.01
)::Matrix{Float64}
    n_age, n_sectors = size(n_recovered)

    for (name, m) in ((:n_dead, n_dead), (:t_ret, t_ret), (:t_entry, t_entry))
        if size(m) != (n_age, n_sectors)
            throw(ArgumentError(
                "`$name` must have size ($n_age, $n_sectors), got $(size(m))"
            ))
        end
    end

    for (name, m) in ((:t_ret, t_ret), (:t_entry, t_entry))
        _validate_time(name, m)
    end

    for (name, v) in ((:p_disab, p_disab), (:p_lab_redn, p_lab_redn), (:p_emp, p_emp))
        _validate_age_sector_param(name, v, n_age, n_sectors)
    end

    if !isnothing(wage) && !isa(wage, Float64) && size(wage) != (n_age, n_sectors)
        throw(ArgumentError(
            "`wage` must have size ($n_age, $n_sectors), got $(size(wage))"
        ))
    end

    # handle proportional calculation
    wage = isnothing(wage) ? 1.0 : wage

    ## calc prop pop disabled and dead
    pop_disab = n_recovered .* p_disab

    # current annual morbidity related loss
    lt = wage .* p_emp .* pop_disab .* p_lab_redn # eqn 22

    # apply for all age groups
    # subtract the sum up to (t_entry - 1) rather than t_entry, so that the
    # entry year itself (i = t_entry, undiscounted when t_entry = 0) is kept
    # rather than cancelled out by the subtraction
    discount = get_discount_sum.(t_ret .+ t_entry, discount_rate) .-
               get_discount_sum.(t_entry .- 1.0, discount_rate)

    loss_disab = lt .* discount
    loss_death = wage .* p_emp .* n_dead .* discount

    return loss_disab + loss_death
end

"""
    calc_fca_cost(n_recovered, n_dead, p_disab, p_lab_redn, p_disab_replaced,
                    t_replacement, wage = nothing, p_emp = 0.8;
                    discount_rate = 0.01)

Calculate the present-value cost of infection-related disability and death
using the Friction Cost Approach (FCA).

The FCA only values output lost during the period needed to replace a worker
(`t_replacement`). Costs are discounted over a window of `t_replacement + 1`
years — the current year, plus `t_replacement` further years — rather than
to retirement, and `n_recovered` and `n_dead` are expected to hold only
current workers. Only a proportion of disabled workers is expected to
require replacement, while all deaths are assumed to require replacement.

# Arguments
- `n_recovered::Matrix{Float64}`: Number of recovered by age group and
    economic sector, of size `(n_age, n_sectors)`. Age groups should hold
    only current workers.
- `n_dead::Matrix{Float64}`: Number of deaths by age group and economic
    sector, of size `(n_age, n_sectors)`. Age groups should hold only
    current workers.
- `p_disab::Union{Float64, Vector{Float64}, Matrix{Float64}}`: Probability
    of long-term disability among recovered. A scalar applies the same
    probability to every age group and sector; alternatively a `Vector` by
    age group (length `n_age`), or a `Matrix` by age group and economic
    sector, of size `(n_age, n_sectors)`, for sector-specific variation.
- `p_lab_redn::Union{Float64, Vector{Float64}, Matrix{Float64}}`:
    Proportional reduction in labour productivity for disabled individuals.
    A scalar applies the same reduction to every age group and sector;
    alternatively a `Vector` by age group (length `n_age`), or a `Matrix` by
    age group and economic sector, of size `(n_age, n_sectors)`, for
    sector-specific variation. Note that this is the proportional
    reduction, and not a scaling factor. To represent a productivity of
    80%, pass 0.2 for a reduction of 20%.
- `p_disab_replaced::Union{Vector{Float64}, Matrix{Float64}}`: Proportion
    of long-term disabled workers who are assumed to be replaced. Either a
    `Vector` by age group (length `n_age`), or a `Matrix` by age group and
    economic sector, of size `(n_age, n_sectors)`, for sector-specific
    variation.
- `t_replacement::Union{Float64, Vector{Float64}}`: Time in years taken to
    replace a worker; the discounted window spans `t_replacement + 1` years
    in total (see above). May be a single value applied to all age groups
    or a vector by age group (length `n_age`).
- `wage::Union{Float64, Matrix{Float64}, Nothing}`: Annual wage, by age
    group and economic sector, of size `(n_age, n_sectors)`. A scalar
    applies the same wage to every age group and sector. If `nothing`
    (default), losses are computed as a proportion of the per-capita annual wage
    (`wage` is treated as `1.0`) rather than in currency units.
- `p_emp::Union{Float64, Vector{Float64}, Matrix{Float64}}`: Probability of
    employment given participation in the labour force. May be a single
    value applied to all age groups and sectors, a `Vector` by age group
    (length `n_age`), or a `Matrix` by age group and economic sector, of
    size `(n_age, n_sectors)` (default: `0.8`).
- `discount_rate::Float64`: Annual discount rate applied to future earnings
    (default: `0.01`). Must be finite and greater than `-1.0`.

# Returns
- `Matrix{Float64}`: Present-value friction cost (or proportional cost, if
    `wage` is `nothing`) from disability and death combined, by age group
    and economic sector, of size `(n_age, n_sectors)`.

# Raises
- `ArgumentError`: if `n_dead` or `wage` (when provided) do not share the
    size `(n_age, n_sectors)` of `n_recovered`; if `t_replacement` (when a
    vector) does not have length `n_age`, or contains a negative or
    non-finite value; if `p_disab`, `p_lab_redn`, `p_disab_replaced`, or
    `p_emp` are a vector without length `n_age`, a matrix without size
    `(n_age, n_sectors)`, or contain a value outside `[0.0, 1.0]`; or if
    `discount_rate` is not finite or not greater than `-1.0`.
"""
function calc_fca_cost(
        n_recovered::Matrix{Float64},
        n_dead::Matrix{Float64},
        p_disab::Union{Float64, Vector{Float64}, Matrix{Float64}},
        p_lab_redn::Union{Float64, Vector{Float64}, Matrix{Float64}},
        p_disab_replaced::Union{Vector{Float64}, Matrix{Float64}},
        t_replacement::Union{Float64, Vector{Float64}},
        wage::Union{Float64, Matrix{Float64}, Nothing} = nothing,
        p_emp::Union{Float64, Vector{Float64}, Matrix{Float64}} = 0.8;
        discount_rate::Float64 = 0.01
)::Matrix{Float64}
    n_age, n_sectors = size(n_recovered)

    if size(n_dead) != (n_age, n_sectors)
        throw(ArgumentError(
            "`n_dead` must have size ($n_age, $n_sectors), got $(size(n_dead))"
        ))
    end

    for (name, v) in (
        (:p_disab, p_disab), (:p_lab_redn, p_lab_redn),
        (:p_disab_replaced, p_disab_replaced), (:p_emp, p_emp))
        _validate_age_sector_param(name, v, n_age, n_sectors)
    end

    if t_replacement isa AbstractVector && length(t_replacement) != n_age
        throw(ArgumentError(
            "`t_replacement` must have length $n_age, got $(length(t_replacement))"
        ))
    end

    _validate_time(:t_replacement, t_replacement)

    if !isnothing(wage) && !isa(wage, Float64) && size(wage) != (n_age, n_sectors)
        throw(ArgumentError(
            "`wage` must have size ($n_age, $n_sectors), got $(size(wage))"
        ))
    end

    # handle proportional calculation
    wage = isnothing(wage) ? 1.0 : wage

    ## calc prop pop disabled and needing replacement
    pop_disab = n_recovered .* p_disab .* p_disab_replaced

    # current annual morbidity related loss
    lt = wage .* p_emp .* pop_disab .* p_lab_redn # eqn 22 from HCA

    # apply for all age groups
    discount = get_discount_sum.(t_replacement, discount_rate)

    loss_disab = lt .* discount
    loss_death = wage .* p_emp .* n_dead .* discount

    return loss_disab + loss_death
end

"""
    calc_healthcare_cost(n_recovered, p_disab, t_life, cost_care;
                          discount_rate = 0.03)

Calculate the present-value cost of long-term treatment and care for
infection-related disability.

Costs accrue immediately (from the
present, ``\\tau = 0``) rather than from a future labour-market entry date.
Healthcare costs are assumed to vary by age only, not by economic sector.

# Arguments
- `n_recovered::Matrix{Float64}`: Number of recovered by age group and
    economic sector, of size `(n_age, n_sectors)`.
- `p_disab::Union{Float64, Vector{Float64}}`: Probability of long-term
    disability among recovered, by age group. Either a single value applied
    to all age groups, or a `Vector` of length `n_age`.
- `t_life::Union{Float64, Vector{Float64}}`: Number of years, from the
    present, over which treatment and care costs are projected — the
    difference between an age group's life expectancy and its
    representative (or median) age; the discounted window spans
    `t_life + 1` years in total. May be a single value applied to all age
    groups, or a `Vector` by age group (length `n_age`).
- `cost_care::Union{Float64, Vector{Float64}}`: Expected annual treatment
    and care cost per disabled individual, by age group. Either a single
    value applied to all age groups, or a `Vector` of length `n_age`.
- `discount_rate::Float64`: Annual discount rate applied to future costs
    (default: `0.03`). Must be finite and greater than `-1.0`.

# Returns
- `Matrix{Float64}`: Present-value treatment and care cost, by age group
    and economic sector, of size `(n_age, n_sectors)`.

# Raises
- `ArgumentError`: if `p_disab` is a vector without length `n_age`, or
    contains a value outside `[0.0, 1.0]`; if `t_life` (when a vector) does
    not have length `n_age`, or contains a negative or non-finite value; if
    `cost_care` is a vector without length `n_age`, or contains a negative
    or non-finite value; or if `discount_rate` is not finite or not greater
    than `-1.0`.
"""
function calc_healthcare_cost(
        n_recovered::Matrix{Float64},
        p_disab::Union{Float64, Vector{Float64}},
        t_life::Union{Float64, Vector{Float64}},
        cost_care::Union{Float64, Vector{Float64}};
        discount_rate::Float64 = 0.03
)::Matrix{Float64}
    n_age, n_sectors = size(n_recovered)

    _validate_age_sector_param(:p_disab, p_disab, n_age, n_sectors)

    if t_life isa AbstractVector && length(t_life) != n_age
        throw(ArgumentError(
            "`t_life` must have length $n_age, got $(length(t_life))"
        ))
    end
    _validate_time(:t_life, t_life)

    if cost_care isa AbstractVector && length(cost_care) != n_age
        throw(ArgumentError(
            "`cost_care` must have length $n_age, got $(length(cost_care))"
        ))
    end

    # reusing useful fn to check finite non-neg vals, disregard name
    _validate_time(:cost_care, cost_care)

    pop_disab = n_recovered .* p_disab
    discount = get_discount_sum.(t_life, discount_rate)

    return pop_disab .* cost_care .* discount
end

end
