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
recovered = ones(n_age, n_sectors);
deaths = copy(recovered) .* 0.02;

# assume age-varying probability of disability
p_disab = collect(1:1:8) ./ 100.0;
p_lab_redn = repeat([0.2, 0.3, 0.4, 0.5], 2);

# assume a uniform probability of employment
p_emp = 0.8;

# assume wages are unity to show losses in terms of current wages
wage = 1.0;
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
recovered = ones(n_age, n_sectors);
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

# assume wages are unity to show losses in terms of current wages
wage = 1.0;

# calculate loss
calc_fca_cost(
    recovered, deaths, p_disab, p_lab_redn, p_disab_replaced, t_replacement,
    wage, p_emp; discount_rate = 0.03
)
```

## Modelling parameter uncertainty

### Uncertainty in fixed parameters

This example shows how to apply a disability cost function across a range of parameter values, using the probability of disability in the human capital method as an example.

```@example param_uncertainty
using Distributions, EpiEconShocks, Random, Statistics

# assume age groups, and unit pop sizes for illustrative purposes
n_age = 8;
n_sectors = 10;
recovered = ones(n_age, n_sectors);
deaths = copy(recovered) .* 0.02;

# assume age-varying productivity reduction
p_lab_redn = repeat([0.2, 0.3, 0.4, 0.5], 2);

# assume a uniform probability of employment
p_emp = 0.8;

# assume wages are unity; may be a matrix for age-sector specific wages
wage = 1.0;

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

## Theory: Human capital approach

The human capital method estimates the value of wages forgone due to the inability of disabled individuals to achieve full productivity in the labour market, and makes the following assumptions for age group ``j`` and economic sector ``k`` at time ``\tau``.

- A proportion ``phi_j \in [0, 1]`` of individuals are recovered from infection and living with lifelong disability;
- A proportion ``e_{j} \in [0, 1]`` are employed; the probability of employment may be age-group specific but is constant over time;
- The labour productivity of disabled and employed individuals is scaled by ``\omega_j``;
- The sector- and age-specific individual annual wage in real terms is ``W_{j,k}``, which is assumed to be constant over time;
- Each age group has ``t^{\text{ret}}`` years of remaining employment after ``t^{\text{entry}}`` years until entry into the labour market, and ``t^{\text{ret}} = a^{\text{ret}} - a_j``, and ``t^{\text{entry}} = a^{\text{entry}} - a_j``, where ``a^{\text{ret}}`` is the age of retirement, ``a^{\text{entry}}`` is the age of labour market entry, and ``a_j`` is the representative age of each group;
- The discount rate for the present value of future wages is ``r``.

The present value of future productivity losses from both current and future workers' disability is:

```math
V^{W+C} = \sum_{j \in J} \sum_{k} Z_{j,k} \sum_{\tau = t^{\text{entry}}}^{t^{\text{entry}} + t^{\text{ret}}} \frac{e_j W_{j,k,\tau} \omega_j}{(1 + r)^\tau}
```

Current workers may be considered to have a time until entry of zero, while future workers should have positive non-zero entry delays.

The present value of future productivity losses due to premature deaths from infection at all ages is similar to that for disabled workers, except it removes productivity scaling and probability of being removed from the workforce (which is assumed 1.0 for deaths).

```math
V^D = \sum_{j \in J} \sum_{k} \dot D_{j,k} \sum_{\tau = t^{\text{entry}}}^{t^{\text{entry}} + t^{\text{ret}}} \frac{e_j W_{j,k,\tau}}{(1 + r)^\tau}
```

The total present value of losses is then ``V^{W+C} + V^D``.

## Theory: Friction cost approach

The friction cost method estimates the value of wages forgone due to the delay in replacing disabled and dead individuals in the labour market, and makes the following assumptions for age group ``j`` and economic sector ``k`` at time ``\tau``.

- A proportion ``phi_j \in [0, 1]`` of individuals are recovered from infection and living with lifelong disability;
- A proportion ``e_{j} \in [0, 1]`` are employed; the probability of employment may be age-group specific but is constant over time;
- The labour productivity of disabled and employed individuals is scaled by ``\omega_j \in [0, 1]``;
- The sector- and age-specific individual annual wage in real terms is ``W_{j,k}, which is assumed to be constant over time``;
- Each age group has a friction period ``d_{j}`` years needed to replace an individual in that age group; this may also be a single value applied to all age groups;
- The proportion of workers in each age group and economic sector that are replaced is ``\rho_{j,k}``;
- The discount rate for the present value of future wages is ``r``.

The present value of future productivity losses from both current and future workers' disability is:

```math
F^W = \sum_{j \in J} \sum_{k} Z_{j,k} \rho_{j,k} \sum_{\tau = 0}^{d_j} \frac{e_j W_{j,k,\tau} \omega_j}{(1 + r)^\tau}
```

Current workers may be considered to have a time until entry of zero, while future workers should have positive non-zero entry delays.

The present value of future productivity losses due to premature deaths from infection at all ages is similar to that for disabled workers, except it removes productivity scaling and probability of being removed from the workforce (which is assumed 1.0 for deaths).

```math
F^D = \sum_{j \in J} \sum_{k} \dot D_{j,k} \sum_{\tau = 0}^{d_j} \frac{e_j W_{j,k,\tau}}{(1 + r)^\tau}
```

The total present value of losses is then ``F^W + F^D``.
