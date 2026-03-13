# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Documentation
- Add docstrings to `cluster_regions()` and `cluster_named_array()` functions in `src/Helpers.jl`
- Document the new `groups` keyword argument in `cluster_named_array()` with Dict and NamedTuple examples
- Align function docstrings and examples with keyword-only argument signatures
- Update `cluster_regions()` docstring to reflect `get_eu_states()` usage
- Document `initial_gtap_model()` with detailed workflow explanation and deepcopy rationale

### Tests
- Add basic test suite for `cluster_named_array()` function in `test/test_cluster_named_array.jl`
- Add test cases for `groups` argument (Dict, NamedTuple, multiple groups)
- Update existing tests to use keyword-only syntax for `fill_value` argument
- Add basic test suite for `cluster_regions()` function in `test/test_cluster_gtap.jl`

