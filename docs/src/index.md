```@meta
CurrentModule = EpiEconShocks
```

# EpiEconShocks

Documentation for [EpiEconShocks](https://github.com/jameel-institute/EpiEconShocks.jl).

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jameel-institute.github.io/EpiEconShocks.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jameel-institute.github.io/EpiEconShocks.jl/dev/)
[![Build Status](https://github.com/jameel-institute/EpiEconShocks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jameel-institute/EpiEconShocks.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jameel-institute/EpiEconShocks.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jameel-institute/EpiEconShocks.jl)

Here is a basic example of the current functionality.

```@example basic_use
using EpiEconShocks

# run the single function shock_gtap() applying a 50% shock over
# 8 quarters
nquarters = 8
shock = repeat([0.5], nquarters)

shock_gtap(nquarters, shock)
```

```@index
```

```@autodocs
Modules = [EpiEconShocks]
```
