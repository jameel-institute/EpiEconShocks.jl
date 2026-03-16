```@meta
CurrentModule = EpiEconShocks
```

# EpiEconShocks

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jameel-institute.github.io/EpiEconShocks.jl/dev/)
[![Build Status](https://github.com/jameel-institute/EpiEconShocks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jameel-institute/EpiEconShocks.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jameel-institute/EpiEconShocks.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jameel-institute/EpiEconShocks.jl)

_EpiEconShocks.jl_ is a proof-of-concept package that demonstrates how to translate epidemic outcomes such as cases, hospitalisations, and deaths into 'shocks' or disruptions to the economic system of the affected population.

_EpiEconShocks.jl_ is currently a thin wrapper around the [_GlobalTradeAnalysisProjectModelV7.jl_ package](https://mivanic.github.io/GlobalTradeAnalysisProjectModelV7.jl/dev/) which implements the GTAP trade model, with wrappers around other economic models under consideration.

## Installation

_EpiEconShocks.jl_ can be installed from GitHub using the Julia package manager _Pkg.jl_.

```julia
using Pkg
Pkg.add(url="git@github.com:jameel-institute/EpiEconShocks.jl.git")
```

## Quick start

Here is a basic example of the current functionality using example data.
A more detailed example may be provided once more detailed data can be shared online.

```@example basic_use
using EpiEconShocks

# run the single function shock_gtap_example() applying a 5% labour shock
EpiEconShocks.Example.shock_gtap_example(0.05)
```

## Related projects

- The Daedalus integrated epi-econ model provided by the R package [_daedalus_](https://jameel-institute.github.io/daedalus/). There is also a lagging Julia translation in the package [_Daedalus.jl_](https://github.com/pratikunterwegs/Daedalus.jl).

- _EpiEconShocks.jl_ wraps the [_GlobalTradeAnalysisProjectModelV7.jl_ package](https://mivanic.github.io/GlobalTradeAnalysisProjectModelV7.jl/dev/) which implements the GTAP trade model.

## Help

To report a bug, request a feature, or just start a discussion, [please open an issue](https://github.com/jameel-institute/EpiEconShocks.jl/issues/new).

## References

WIP
