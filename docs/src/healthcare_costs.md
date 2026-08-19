```@meta
CurrentModule = EpiEconShocks
```

# Estimating healthcare costs of long-term disability

Disease-related disability may generate persistent treatment and care costs.
These costs are conceptually distinct from the forgone wages estimated by the human capital and friction cost approaches (see [Estimating the productivity costs of long-term disability](@ref)).
_EpiEconShocks.jl_ can help to quantify the treatment and care costs associated with infection-linked long-term disability from an epidemic.

## Using package functionality to calculate healthcare costs

_EpiEconShocks.jl_ provides the function `calc_healthcare_cost` to calculate healthcare costs.

We make two simplifying assumptions: disability is assumed to be life-long, and the starting point of disability is assumed to be some arbitrary end-date of a pandemic.
This may lead to an under-estimate of healthcare costs of an individual affected early in a multi-year pandemic.

Healthcare costs accrue immediately for all age groups, rather than from a future labour-market entry date, and are projected out over `t_life`, the number of years remaining between an age group's representative age (the mean or median) and its life expectancy, which may extend beyond retirement.
Unlike `calc_hca_cost` and `calc_fca_cost`, healthcare costs are assumed to vary by age group only, and not by economic sector, since treatment and care needs are more closely tied to age-related morbidity than to occupation.

```@example healthcare_cost
using EpiEconShocks

n_age = 8;
n_sectors = 10;
recovered = 1e5 .* ones(n_age, n_sectors);

# assume age-varying probability of disability
p_disab = collect(1:1:8) ./ 100.0;

# years remaining between each age group's representative age and its life
# expectancy, over which care costs are projected (may extend beyond
# working age)
t_life = [70.0, 65.0, 60.0, 55.0, 45.0, 30.0, 20.0, 10.0];

# assume an annual per-capita treatment and care cost, uniform over age
cost_care = 5e3;

calc_healthcare_cost(recovered, p_disab, t_life, cost_care; discount_rate = 0.03)
```

`p_disab` and `cost_care` may also vary by age group, by passing a `Vector{Float64}` of length `n_age` in place of a scalar, as shown above for `p_disab`.

## Theory: Healthcare cost approach

The healthcare cost method estimates the present value of treatment and care costs for individuals living with lifelong disability, and makes the following assumptions for age group ``j`` at time ``\tau`` years from the present.

- A proportion ``\phi_{j} \in [0, 1]`` of individuals recovered from infection in age group ``j`` are living with lifelong disability, giving a disabled population ``Z_{j}(t)``;
- The expected annual treatment and care cost per disabled individual in age group ``j`` is ``c_{j, \tau}``, assumed constant over the projection window;
- Costs are projected from the present (``\tau = 0``) out to ``t^{\text{life}}_j``, the number of years between age group ``j``'s life expectancy and its representative (or median) age, which may extend beyond the terminal working age ``a^{\text{ret}}`` used in the human capital and friction cost approaches;
- The discount rate for the present value of future costs is ``r``.

The present value of future treatment costs is:

```math
\mathcal{T}_{t} = \sum_{j \in J} Z_{j}(t) \sum_{\tau=0}^{t^{\text{life}}_j} \frac{c_{j,t+\tau}}{(1+r)^{\tau}}
```
