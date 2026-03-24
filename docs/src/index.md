```@meta
CurrentModule = EpiEconShocks
```

# EpiEconShocks.jl

[![Project Status: Concept – Minimal or no implementation has been done yet, or the repository is only intended to be a limited example, demo, or proof-of-concept.](https://www.repostatus.org/badges/latest/concept.svg)](https://www.repostatus.org/#concept)
[![Version](https://img.shields.io/badge/version-0.0.6-aquamarine.svg)](https://jameel-institute.github.io/EpiEconShocks.jl/dev/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jameel-institute.github.io/EpiEconShocks.jl/dev/)
[![Build Status](https://github.com/jameel-institute/EpiEconShocks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jameel-institute/EpiEconShocks.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jameel-institute/EpiEconShocks.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jameel-institute/EpiEconShocks.jl)
[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)

_EpiEconShocks.jl_ is a proof-of-concept package that demonstrates how to translate epidemic outcomes such as cases, hospitalisations, and deaths into 'shocks' or disruptions to the economic system of the affected population.

_EpiEconShocks.jl_ is developed at the [Jameel Institute](https://www.imperial.ac.uk/jameel-institute/) at Imperial College London as part of the [Jameel Institute-Kenneth C. Griffin Initiative for the Economics of Pandemic Preparedness (EPPI)](https://new.express.adobe.com/webpage/TXLBkz1sN9FI5?), in collaboration with the [RESIDE research software engineering team](https://reside-ic.github.io/about/).

_EpiEconShocks.jl_ is currently a thin wrapper around the [_GlobalTradeAnalysisProjectModelV7.jl_ package](https://mivanic.github.io/GlobalTradeAnalysisProjectModelV7.jl/dev/) which implements the GTAP trade model, with wrappers around other economic models under consideration.

## Installation

_EpiEconShocks.jl_ can be installed from GitHub using the Julia package manager _Pkg.jl_.

```julia
using Pkg
Pkg.add(url="git@github.com:jameel-institute/EpiEconShocks.jl.git")
```

## Quick start

Here is a basic example of the current functionality using example GTAP data.
A more detailed example may be provided once more detailed data can be shared online.

First, create a `ParameterShock` object that specifies the parameter set, and the sectors within the set, that are to be shocked.
Shocks should be represented as scaling factors in the range ``[0.0, 1.0]``; users must take care to convert an estimated reduction in labour or consumption to the appropriate value of scaling factor (e.g. represent a labour shock of 10% as a labour scaling factor of 0.9).

`ParameterShock` objects must be passed to the main function `shock_gtap` as a `Vector`, which allows passing multiple shocks at once.

```@example basic_use
using EpiEconShocks

example_model = EpiEconShocks.Example.get_example_model();

# run the single function shock_gtap_example() applying a 5% labour shock,
# and a 20% shock to consumption of services
labour_shock = EpiEconShocks.ParameterShock("qe", ["skilled labor", "unskilled labor"], 0.05)
svces_shock = EpiEconShocks.ParameterShock("qpa", "svces", 0.2)

output = EpiEconShocks.Example.shock_gtap_example(
    example_model, [labour_shock, svces_shock])

# examine proportional change in GDP
output.delta_gdp
```

## Further documentation

Further long-form documentation, a package index, and function documentation may be found at the [package website](https://jameel-institute.github.io/EpiEconShocks.jl/dev/).

## Future development

This project is currently a work in progress.
Future development may include the following:

- More options for how GTAP endowments and commodities can be aggregated;

- More fine-scaled control over the scaling applied to each sector within the GTAP regions, commodities, and endowments sets; for example, the ability to model a pandemic shock in a single region to examine global impacts, and similar for commodity demand.

- Better documentation of how epidemic shocks can be modelled in more details, for example to include long-term impacts such as reductions in population size or increases in epidemic-related disability.



## Related projects

- The Daedalus integrated epidemiological and macro-economic model, available as an R package [_daedalus_](https://jameel-institute.github.io/daedalus/). There is also a lagging Julia translation in the package [_Daedalus.jl_](https://github.com/pratikunterwegs/Daedalus.jl).

- _EpiEconShocks.jl_ wraps the [_GlobalTradeAnalysisProjectModelV7.jl_ package](https://mivanic.github.io/GlobalTradeAnalysisProjectModelV7.jl/dev/) which implements the GTAP version 7 trade model, which compatible with version 11 GTAP data (year 2017). Compatibility with other versions of the GTAP database is not assured.

## Help

To report a bug, request a feature, or start a discussion, [please open an issue](https://github.com/jameel-institute/EpiEconShocks.jl/issues/new).

## References

WIP
