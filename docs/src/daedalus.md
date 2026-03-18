```@meta
CurrentModule = EpiEconShocks
```

## Using EpiEconShocks.jl with realistic epidemic outcomes

This example shows how to use EpiEconShocks.jl with realistic epidemic model outputs.

We use the Julia implementation of the Daedalus model provided [in Daedalus.jl](https://pratikunterwegs.github.io/Daedalus.jl/dev/) to provide epidemic trajectories for this example.

**Note that** this is a proof-of-concept and a work in progress.

```@example using_daedalus
using Daedalus
using EpiEconShocks
using Plots

output = daedalus("United Kingdom", "influenza 2009", time_end=100.0);
horizon = 100

workers = sum(Daedalus.DataLoader.get_country("United Kingdom").workers)

# get cumulative number of infectious symptomatic, hospitalised, and dead
# in each quarter
working_groups = 5:49

labour_loss = sum(
        Daedalus.Outputs.get_values(output, "Is", horizon, working_groups) .+
        Daedalus.Outputs.get_values(output, "H", horizon, working_groups) .+
        Daedalus.Outputs.get_values(output, "D", horizon, working_groups)
    )

labour_prop_loss = labour_loss / (workers * horizon)

labour_available = 1.0 - labour_prop_loss
```

Next we pass the proportional losses in labour supply to the function `shock_gtap()` to compute new equilibria for each level of available labour supply.

```@example using_daedalus
# pass a shock to a model using example data and view outputs
# assumes equal shocks to all regions
example_model = EpiEconShocks.Example.get_example_model();

labour_shock = ParameterShock(
    "qe", ["skilled labor", "unskilled labor"], labour_available
)

gtap_output = EpiEconShocks.Example.shock_gtap_example(example_model, [labour_shock]);

gtap_output.y
```

```@example using_daedalus
gtap_output.ev
```

```@example using_daedalus
gtap_output.delta_gdp
```
