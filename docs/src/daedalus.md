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

quarter_length = 90
nquarters = 8
time_end = float(nquarters * quarter_length)

output = daedalus(r0=3.0, time_end=time_end);

# get cumulative number of infectious symptomatic, hospitalised, and dead
# in each quarter
working_groups = 5:49

labour_loss =
    Daedalus.Outputs.get_values(output, "Is", quarter_length, working_groups) .+
    Daedalus.Outputs.get_values(output, "H", quarter_length, working_groups) .+
    Daedalus.Outputs.get_values(output, "D", quarter_length, working_groups)

labour_prop_loss = labour_loss ./
    (sum(Daedalus.Data.aus_workers() * quarter_length))

# plot proportional loss in labour supply in each quarter
plot(labour_prop_loss * 100)
xlabel!("# Economic quarter (90 days)")
ylabel!("% labour supply lost")
```

Next we pass the proportional losses in labour supply to the function `shock_gtap()` to compute new equilibria for each level of available labour supply.

```@example using_daedalus
# calculate available labour from proportion lost
labour_available = 1.0 .- labour_prop_loss

# run model and view outputs
gtap_output = shock_gtap(nquarters, labour_available);

gtap_output.y_by_q
```

```@example using_daedalus
gtap_output.ev_by_q
```
