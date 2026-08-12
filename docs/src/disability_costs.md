```@meta
CurrentModule = EpiEconShocks
```

# Estimating the long-term disability costs of an epidemic

_EpiEconShocks.jl_ can help to quantify the costs associated with wages lost due to infection-linked long-term disability or death due to an epidemic.

The package implements two approaches, a human capital (HC) approach and a friction cost (FC) approach.

## Human capital method

The human capital approach is implemented using the function `calc_hca_cost`.

The function accepts a matrix of the number of recovered individuals per age-group and economic sector, a similar matrix for age-and-sector deaths; it also requires the proportion of recovered who are disabled long-term in each age group, the proportional labour reduction for these individuals, the probability of employment at any time ``t`` (which may be age-specific), and the expected wage at current values per age and sector.

Users can also pass a discount rate, and specify the time until retirement of current workers, as well as the time until workforce entry and eventual retirement of the future workforce who may be affected by disability.

The example below shows how to use this function.

### Basic setup of counts and proportions

```@example hca_cost
using EpiEconShocks

# assume age groups, and unit pop sizes for illustrative purposes
n_age = 8;
n_sectors = 10;
# assume 100,000 recovered individuals for this example, per sector and age
recovered = 1e5 .* ones(n_age, n_sectors);
deaths = copy(recovered) .* 0.02;

# assume age-varying probability of disability
p_disab = collect(1:1:8) ./ 100.0;
p_lab_redn = repeat([0.2, 0.3, 0.4, 0.5], 2);

# assume a uniform probability of employment
p_emp = 0.8;

# assume median wage uniform over age and economic sector
wage = 40e3;
```

### Varying labour-market entry and exit

`calc_hca_cost` allows specifying age and sector specific times of labour market entry and exit, so that the lost wages of current and future workers can both be estimated.

The function accepts matrices of the same dimensions as the number of recovered and dead for `t_entry` the time to labour market entry, and `t_ret` the time to labour market exit following entry.
For current workers, the time to entry is zero.

```@example hca_cost
# time to entry and exit
t_entry = ones(n_age, n_sectors) .* [18, 15, 12, 1, 0, 0, 0, 0];
t_ret = ones(n_age, n_sectors) .* [50, 50, 50, 50, 40, 25, 15, 5]
```

The net present value of total lost wages can be calculated by passing a discount rate.

```@example hca_cost
calc_hca_cost(
    recovered, deaths, p_disab, p_lab_redn, t_ret, t_entry, wage, p_emp; 
    discount_rate = 0.03
)
```

The output can be aggregated by age group or economic sector for further use.

## Friction cost method

The friction cost method is similar to the human capital method, but only considers wages lost during the time taken to replace a disabled or dead worker.

It does not account for the wages lost due to disability or death in the future workforce, as there is no present cost to replacing these individuals.

_EpiEconShocks.jl_ provides the function `calc_fca_cost` to get lost wages using the FC approach.

```@example fca_cost
using EpiEconShocks

# assume age groups, and unit pop sizes for illustrative purposes
n_age = 4;
n_sectors = 10;
# assume 100,000 recovered individuals for this example, per sector and age
recovered = 1e5 .* ones(n_age, n_sectors);
deaths = copy(recovered) .* 0.02;

# assume age-varying probability of disability
p_disab = collect(2:2:8) ./ 100.0;
p_lab_redn = [0.2, 0.3, 0.4, 0.5];

# assume that only a proportion of disabled workers are replaced per age group
p_disab_replaced = repeat([0.2], n_age);

# assume a uniform probability of employment
p_emp = 0.8;

# assume a time for replacement, by age group
t_replacement = [0.25, 0.5, 0.67, 0.25];

# assume median wage uniform over age and economic sector
wage = 40e3;

# calculate loss
calc_fca_cost(
    recovered, deaths, p_disab, p_lab_redn, p_disab_replaced, t_replacement,
    wage, p_emp; discount_rate = 0.03
)
```

## Sector heterogeneity

The examples above vary ``\phi`` (`p_disab`), ``\omega`` (`p_lab_redn`), and ``e`` (`p_emp`) — and, for `calc_fca_cost`, ``\rho`` (`p_disab_replaced`) — by age group only, passing each as a `Vector{Float64}` of length `n_age`.

These parameters may instead vary by economic sector as well as age group, by passing a `Matrix{Float64}` of size `(n_age, n_sectors)` in place of the vector.
This is useful, for example, when a manual-labour sector is assumed to carry a higher probability of long-term disability than an office-based sector, for workers of the same age.

```@example hca_sector
using EpiEconShocks

n_age = 8;
n_sectors = 2; # e.g. "office" and "manual_labour"

# assume 100,000 recovered individuals for this example, per sector and age
recovered = 1e5 .* ones(n_age, n_sectors);
deaths = copy(recovered) .* 0.02;

p_lab_redn = repeat([0.2, 0.3, 0.4, 0.5], 2);
p_emp = 0.8;
wage = 40e3;

t_entry = ones(n_age, n_sectors) .* [18, 15, 12, 1, 0, 0, 0, 0];
t_ret = ones(n_age, n_sectors) .* [50, 50, 50, 50, 40, 25, 15, 5];

# age-varying probability of disability, doubled in the manual-labour sector
p_disab_age = collect(1:1:8) ./ 100.0;
p_disab_sector = hcat(p_disab_age, p_disab_age .* 2);

calc_hca_cost(
    recovered, deaths, p_disab_sector, p_lab_redn, t_ret, t_entry, wage, p_emp;
    discount_rate = 0.03
)
```

Vector and matrix parameters can be freely mixed within a single call: `p_disab` above varies by age and sector, while `p_lab_redn` and `p_emp` continue to vary by age only.
The same applies to `calc_fca_cost`, including its additional `p_disab_replaced` parameter.

`n_recovered`, `n_dead`, `t_ret`, `t_entry`, `t_replacement`, and `wage` are unaffected by this and continue to be specified as before (see the function docstrings).

## Extension uncertainty in fixed parameters

This example shows how to apply a disability cost function across a range of parameter values, using the probability of disability in the human capital method as an example.

```@example param_uncertainty
using Distributions, EpiEconShocks, Random, Statistics

# assume age groups, and unit pop sizes for illustrative purposes
n_age = 8;
n_sectors = 10;
# assume 100,000 recovered individuals for this example, per sector and age
recovered = 1e5 .* ones(n_age, n_sectors);
deaths = copy(recovered) .* 0.02;

# assume age-varying productivity reduction
p_lab_redn = repeat([0.2, 0.3, 0.4, 0.5], 2);

# assume a uniform probability of employment
p_emp = 0.8;

# assume median wage uniform over age and economic sector
wage = 40e3;

# time to entry and exit
t_entry = ones(n_age, n_sectors) .* [18, 15, 12, 1, 0, 0, 0, 0];
t_ret = ones(n_age, n_sectors) .* [50, 50, 50, 50, 40, 25, 15, 5];
```

Model uncertainty in the age-specific probability of disability.

```@example param_uncertainty
p_disab = collect(1:1:8) ./ 100.0;

# select
d = Normal(0.0, 0.05);
samples = 1000;
p_disab_list = [
    clamp.(p_disab .+ rand(d, n_age), 0.0, 1.0) for i in 1:samples];

# result has size (n_age, n_sectors, samples)
result = stack([calc_hca_cost(
    recovered, deaths, pdsb, p_lab_redn, t_ret, t_entry;
    discount_rate = 0.03
) for pdsb in p_disab_list]);
```

```@example param_uncertainty
# see the age and sector specific median:
result_median = dropdims(median(result; dims = 3); dims = 3)
```

```@example param_uncertainty
# see age and sector specific quantiles
result_quantiles = mapslices(x -> quantile(x, [0.025, 0.975]), result; dims = 3)
```

The resulting age- and sector-specific summary statistics can be used to create figures or tables.

## Extension: Modelling reduced educational attainment

Educational attainment for future workers (children) may be reduced by pandemic related disruptions, which include missed education due to infection and mitigation measures that result in lower efficacy of instruction.

This can be included in the human capital method which values the productivity loss of future workers.

The effect of reduced educational attainment may be assumed to have a scaling effect on wages.
The wage expected to be attained will depend on the proportion of education missed relative to the pre-pandemic norm, and the education coefficient of wages (see [mincer1974](@citet)).

```math
    W^{1}_{j,k,\tau} = W^{0}_{j,k,\tau} e^{\left(-\beta^{\text{Edu}}\Delta \text{Edu}_j \right)}
```

Assuming a value of ``\beta^{\text{Edu}}`` of 0.04 following [ge2013](@citet), we can calculate the reduced expected wage due to lower educational attainment as shown in the following code snippet.
We assume that the loss in educational attainment is 0.1 or 10% of the expected pre-pandemic attainment.

First we set up the initial epidemic outcomes and population parameters.

```@example edu_loss
# set up initial population parameters
using EpiEconShocks

n_age = 2; # only modelling future and current workers
n_sectors = 1;
# assume 100,000 recovered individuals for this example, per sector and age
recovered = 1e5 .* ones(n_age, n_sectors);
deaths = copy(recovered) .* 0.02;

# assume a uniform productivity reduction
p_lab_redn = [0.2, 0.2];

# assume a uniform probability of employment
p_emp = 0.8;

# uniform prob of disability
p_disab = [0.2, 0.2];

# assume median wage for both age groups
wage = 40e3;

# time to entry and exit
t_entry = ones(n_age, n_sectors) .* [10, 0];
t_ret = ones(n_age, n_sectors) .* [50, 25];
```

We calculate ``W^{1}_{j,k,\tau}`` for each age group.
With only two age groups (future; ``j = 1`` and current workers; ``j = 2``), ``W^{1}_{1,k,\tau}`` is scaled only for ``j = 1``.

**Note that** since current workers are not assumed to be affected, the corresponding values of ``\beta^{\text{Edu}}_j`` and ``\Delta \text{Edu}_j`` are 0.0 for ``j = 2``; they are specified only to satisfy the vectorised operation in Julia.

```@example edu_loss
wage = reshape(wage .* exp.([-0.04, 0.0] .* [0.1, 0.0]), n_age, n_sectors);
```

We can now pass the age-scaled wage array (in this case, a vector as values are uniform over sectors) to `calc_hca_costs`.

```@example edu_loss
calc_hca_cost(
    recovered, deaths, p_disab, p_lab_redn, t_ret, t_entry, wage, p_emp;
    discount_rate = 0.03
)
```

## Theory: Human capital approach

The human capital method estimates the value of wages forgone due to the inability of disabled individuals to achieve full productivity in the labour market, and makes the following assumptions for age group ``j`` and economic sector ``k`` at time ``\tau``.

- A proportion ``\phi_{j,k} \in [0, 1]`` of individuals are recovered from infection and living with lifelong disability;
- A proportion ``e_{j,k} \in [0, 1]`` are employed; the probability of employment may be age- and sector-specific but is constant over time;
- The labour productivity of disabled and employed individuals is scaled by ``\omega_{j,k}``;
- The sector- and age-specific individual annual wage in real terms is ``W_{j,k}``, which is assumed to be constant over time;
- Each age group has ``t^{\text{ret}}`` years of remaining employment after ``t^{\text{entry}}`` years until entry into the labour market, and ``t^{\text{ret}} = a^{\text{ret}} - a_j``, and ``t^{\text{entry}} = a^{\text{entry}} - a_j``, where ``a^{\text{ret}}`` is the age of retirement, ``a^{\text{entry}}`` is the age of labour market entry, and ``a_j`` is the representative age of each group;
- The discount rate for the present value of future wages is ``r``.

The present value of future productivity losses from both current and future workers' disability is:

```math
V^{W+C} = \sum_{j \in J} \sum_{k} Z_{j,k} \sum_{\tau = t^{\text{entry}}}^{t^{\text{entry}} + t^{\text{ret}}} \frac{e_{j,k} W_{j,k,\tau} \omega_{j,k}}{(1 + r)^\tau}
```

Current workers may be considered to have a time until entry of zero, while future workers should have positive non-zero entry delays.

The present value of future productivity losses due to premature deaths from infection at all ages is similar to that for disabled workers, except it removes productivity scaling and probability of being removed from the workforce (which is assumed 1.0 for deaths).

```math
V^D = \sum_{j \in J} \sum_{k} \dot D_{j,k} \sum_{\tau = t^{\text{entry}}}^{t^{\text{entry}} + t^{\text{ret}}} \frac{e_{j,k} W_{j,k,\tau}}{(1 + r)^\tau}
```

The total present value of losses is then ``V^{W+C} + V^D``.

## Theory: Friction cost approach

The friction cost method estimates the value of wages forgone due to the delay in replacing disabled and dead individuals in the labour market, and makes the following assumptions for age group ``j`` and economic sector ``k`` at time ``\tau``.

- A proportion ``\phi_{j,k} \in [0, 1]`` of individuals are recovered from infection and living with lifelong disability;
- A proportion ``e_{j,k} \in [0, 1]`` are employed; the probability of employment may be age- and sector-specific but is constant over time;
- The labour productivity of disabled and employed individuals is scaled by ``\omega_{j,k} \in [0, 1]``;
- The sector- and age-specific individual annual wage in real terms is ``W_{j,k}``, which is assumed to be constant over time``;
- Each age group has a friction period ``d_{j}`` years needed to replace an individual in that age group; this may also be a single value applied to all age groups;
- The proportion of workers in each age group and sector that need replacement is ``\rho_{j,k}``;
- The discount rate for the present value of future wages is ``r``.

The present value of future productivity losses from both current and future workers' disability is:

```math
F^W = \sum_{j \in J} \sum_{k} Z_{j,k} \rho_{j,k} \sum_{\tau = 0}^{d_j} \frac{e_{j,k} W_{j,k,\tau} \omega_{j,k}}{(1 + r)^\tau}
```

The present value of future productivity losses due to premature deaths from infection at all ages is similar to that for disabled workers, except it removes productivity scaling and probability of being removed from the workforce (which is assumed 1.0 for deaths).

```math
F^D = \sum_{j \in J} \sum_{k} \dot D_{j,k} \sum_{\tau = 0}^{d_j} \frac{e_{j,k} W_{j,k,\tau}}{(1 + r)^\tau}
```

The total present value of losses is then ``F^W + F^D``.

## References

```@bibliography
```
