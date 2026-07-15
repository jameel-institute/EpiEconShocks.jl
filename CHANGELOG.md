# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Module LtCosts with functions for calculating the cost in terms of lost wages of long-term infection-related disability and death, using the Human Capital Approach and Friction Cost Approach;
- Basic test suites for functions implementing HCA and FCA approaches, including a test showing the two approaches agree exactly under equivalent assumptions;
- Long-form documentation showing how to use new functionality to simulate the long-term costs of an epidemic with parameter uncertainty.

## [0.0.10] - 2026-06-08

### Added

- `calc_labour_avail()` replaces `calc_indivs()`: takes long-format sector-stratified epidemiological data (one row per time–sector pair) and returns a `Vector{Float64}` of labour availability fractions. Adds explicit `wfh` and `p_furl` parameters (scalar or vector) for per-sector work-from-home capability and furlough rates. WFH modulates the absence contribution of mildly symptomatic workers via a `productivity_mild` keyword (default 0.5). Furlough is applied multiplicatively on top of illness availability.
- Input validation for `calc_labour_avail()`: validates that `n_adults`, `n_school`, and `n_workers` are non-negative; that `n_workers` vector length matches number of sectors; and that all scaling parameters (`scaling_affected`, `scaling_wfh`, `scaling_care`, `scaling_furl`) are in [0.0, 1.0].
- Comprehensive test suite for `calc_labour_avail()` using Daedalus epidemiological data, covering basic functionality, scalar and vector parameters, and input validation.
- `get_example_epi_data()`: loads example epidemiological data from Daedalus model outputs for use in examples and testing.

- Added `codecov.yml` for Codecov.io

### Changed

- `calc_labour_avail()`: `N_work`, `wfh`, and `p_furl` now accept `AbstractVector` instead of `Dict` for per-sector values. Vector element `j` corresponds to the `j`-th sector in sorted order of unique sector labels in the data. Scalar inputs are unchanged.
- `calc_labour_avail()` no longer calls the removed `calc_indivs()`; weighted absence is now computed directly.
- `calc_consumption_avail()`: signature changed from `(deaths::AbstractVector, phi)` to `(df::DataFrame, phi; comp_deaths, col_sector)`. Deaths are now read from a long-format epidemiological DataFrame, filtered by the `comp_deaths` compartment name(s) (default `"dead"`), summed across all sectors, and differenced internally to derive new deaths before applying the exponential decay.

## [0.0.9] - 2026-03-27

### Changed

- Fixed `cluster_commodities` to not use broadcasting when setting single elements of commodities `NamedArray`

## [0.0.8] - 2026-03-26

### Features

- Expanded to ten sector configuration based on ISIC v4

### Changed

- Defined ten new commodity categories for allprimary, manufac, utilities, constr, retail, transport, hosp, ict_prof_serv, pubadm, arts_rec_other in `cluster_commodities()`

## [0.0.7] - 2026-03-26

### Features

- Add `calc_labour_avail()` to convert epidemiological compartment data into daily labour availability fractions
- Add `calc_consumption_avail()` to model consumption reduction from infection-avoidance behaviour driven by deaths
- Add `integrate_shock()` to compute time-weighted average shocks from daily availability time series
- Export `compare_gtaps()` function for public use in extracting economic outcomes from GTAP model comparisons
- Extend `ParameterShock` struct to support region-specific scaling via `NamedArray` scaling factors
- Enable applying different scaling factors to different regions and commodities in GTAP models

### Changed

- Update `shock_gtap()` docstring to accurately reflect return type (`GTAP.model_container_struct` instead of named tuple)
- Enhance `shock_gtap()` documentation with workflow guidance pointing to `compare_gtaps()` for outcome extraction
- Fix `compare_gtaps()` function implementation: initialize `y` and `ev` NamedArrays before use
- Expand `compare_gtaps()` docstring with comprehensive documentation of return values and usage examples
- Enhance `scale` field in `ParameterShock` to accept `Union{Float64, Vector{Float64}, NamedArray}`
- Update `ParameterShock` validation to support NamedArray scaling with named dimensions for regions/commodities
- Refactor `_apply_shocks!()` to handle NamedArray scaling factors
- Improve `_apply_shocks!()` to extract region information from NamedArray dimension names
- Simplify region-specific shock application by leveraging NamedArray's named dimensions

### Tests

- Add comprehensive test suite for `compare_gtaps()` in `test/test_compare_gtaps.jl`
- Tests cover: output structure validation, dimensional consistency, region name preservation, determinism, identity shocks
- Add tests for `ParameterShock` with NamedArray scaling in `test/test_struct_paramShock.jl`
- Add validation tests for region-specific shock combinations in `test/test_shock_gtap.jl`

## [0.0.6] - 2026-03-24

### Features

- Export `ROI` constant from `Helpers` module for regions of interest
- Support vector scaling in `ParameterShock` struct: `scale` field now accepts `Union{Float64, Vector{Float64}}`

### Changed

- Improve `cluster_named_array()` implementation to handle preserve values that may not exist in input array
- Refactor `cluster_regions()` to use `ROI` constant as default preserve list instead of hardcoded values
- Enhance `ParameterShock` constructor validation to support per-index scaling factors
- Refactor `initial_gtap_model()` to use `ROI` constant from Helpers module for default regions of interest
- Add special commodity category for transport, hospitality, and leisure in `cluster_commodities()`

### Documentation

- Clarify `cluster_regions()` behavior with EU member state aggregation

### Tests

- Add comprehensive tests for vector scaling in `ParameterShock` struct

## [0.0.5] - 2026-03-23

### Changed

- Relax `ParameterShock` scale validation: accept any `scale > 0.0` instead of restricting to `[0.0, 1.0]`
- Update `ParameterShock` docstring to reflect new validation rules
- Enhance `_apply_shocks!` to support both 2D and 3D arrays
- Fix spelling of labour in `cluster_endowments()`

### Documentation

- Expand setup guide with GTAP database source information
- Document `ModelInit.initial_gtap_model` function and its default aggregation behavior
- Add info boxes for commodity and endowment aggregation details
- Clarify warnings about memory usage and aggregation recommendations
- Update version badges in README and documentation to 0.0.5

## [0.0.4] - 2026-03-19

- Add helper function `calc_indivs` in module `EpiHelpers`

## [0.0.3] - 2026-03-18

### Features

- Add `delta_gdp` output from `shock_gtap`

### Changed

- Change internal copy logic in `shock_gtap`

### Documentation

- Update documentation for new `shock_gtap` output
- Update documentation badges to show versions

## [0.0.2] - 2026-03-17

### Features

- Add `ParameterShock` struct to enable flexible, multi-parameter economic shocks with validation
- Add `_apply_shocks!` internal helper to apply vector of parameter shocks to model data

### Changed

- Refactor `shock_gtap()` signature: now accepts `Vector{ParameterShock}` instead of `labour_scaling::Float64` for flexible parameter targeting

### Documentation

- Add comprehensive docstring to `ParameterShock` struct with field descriptions and usage examples
- Add docstring to `shock_gtap()` function with example of using `ParameterShock` vector

### Tests

- Add validation tests for `ParameterShock` struct in `test/test_shock_gtap.jl` (valid construction, boundary values, ArgumentError cases)
- Update `shock_gtap()` test to use new `ParameterShock` vector API

## [0.0.1] - 2026-03-13

### Features

- Generalize `cluster_named_array()` with optional `groups` keyword argument to support native grouping of non-preserved elements
- Simplify `cluster_regions()` to use the new `groups` mechanism for EU member state mapping
- Extract EU member states list into reusable `get_eu_states()` function
- Add comprehensive docstring to `initial_gtap_model()` function

### Changed

- Refactor `cluster_named_array()` signature: `fill_value` is now a keyword-only argument for improved clarity
- Refactor `cluster_regions()` signature: `fill_value` is now a keyword-only argument
- Update `cluster_regions()` to pass `roi` argument to `cluster_regions()` function
- Reduce Julia version requirement to 1.10.0
- Add explicit StyledStrings dependency constraint (v1.10) for Julia 1.10 compatibility

### Documentation

- Add docstrings to `cluster_regions()` and `cluster_named_array()` functions in `src/Helpers.jl`
- Document the new `groups` keyword argument in `cluster_named_array()` with Dict and NamedTuple examples
- Align function docstrings and examples with keyword-only argument signatures
- Update `cluster_regions()` docstring to reflect `get_eu_states()` usage
- Document `initial_gtap_model()` with detailed workflow explanation and deepcopy rationale
- Add docstrings to `cluster_commodities()` and `cluster_endowments()` functions to enable Documenter.jl cross-references in setup guide

### Tests

- Add basic test suite for `cluster_named_array()` function in `test/test_cluster_named_array.jl`
- Add test cases for `groups` argument (Dict, NamedTuple, multiple groups)
- Update existing tests to use keyword-only syntax for `fill_value` argument
- Add basic test suite for `cluster_regions()` function in `test/test_cluster_gtap.jl`
- Add basic test suite for `shock_gtap_example()` function in `test/test_shock_gtap_example.jl`
- Add basic test suite for `shock_gtap()` function in `test/test_shock_gtap.jl`
