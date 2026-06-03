```@meta
CurrentModule = EpiEconShocks
```

## Estimating labour and consumption over an epidemic

This example shows how to estimate labour and consumption over an epidemic using example epidemiological data.

### Labour availability

Load the example data and filter to the working-age population:

```@example estimating_labour
using EpiEconShocks, DataFrames

df = EpiEconShocks.Example.get_example_epi_data()

# Filter to working-age population, excluding non-working sectors
df_work = filter(
    row -> row.age_group == "20-64" &&
           row.vaccine_group == "unvaccinated" &&
           row.econ_sector != "sector_00",
    df
)

# Extract worker counts by sector at baseline
n_workers = filter(
    row -> row.time == minimum(df_work.time) &&
           row.compartment == "susceptible",
    df_work
)[:, "value"]

n_adults = sum(n_workers)
n_school = 5_000_000.0 # arbitrary assumption of number of school children
```

Calculate labour availability over the epidemic:

```@example estimating_labour
labour_avail = EpiEconShocks.EpiHelpers.calc_labour_avail(
    df_work, n_workers, n_adults, n_school
)
```

The result is a matrix of dimensions $[1, N]$ with values in [0, 1] indicating the fraction of available labour in each economic sector for $N$ economic sectors.

## References

WIP
