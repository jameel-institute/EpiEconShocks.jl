# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.6] - 2026-03-24

### Features
- Export `ROI` constant from `Helpers` module for regions of interest
- Support vector scaling in `ParameterShock` struct: `scale` field now accepts `Union{Float64, Vector{Float64}}`

### Changed
- Improve `cluster_named_array()` implementation to handle preserve values that may not exist in input array
- Refactor `cluster_regions()` to use `ROI` constant as default preserve list instead of hardcoded values
- Enhance `ParameterShock` constructor validation to support per-index scaling factors

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
