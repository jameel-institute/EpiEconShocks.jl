# EpiEconShocks.jl: Translate epidemic model outcomes into economic model inputs

This is a repo that hosts the Julia package EpiEconShocks.jl. You are building a Julia package that can ingest the outputs of any arbitary epidemic model into inputs suitable for a range of models used in macro-economics.

The general template of epidemic model outputs are expected to be a timeseries of the prevalence of infections, and hospitalisations, and a timeseries of deaths (new or total deaths).

Examples include:

- **Daedalus.jl** (https://github.com/jameel-institute/Daedalus.jl): an SEIR epidemic model.

Examples of macro-economc models for which inputs are required are:

- **NiGEM** (https://niesr.ac.uk/nigem-macroeconomic-model): source code is not available;
- **Global Trade Analysis Project** (github.com/mivanic/GlobalTradeAnalysisProjectModelV7.jl): source code of a Julia implementation of the Global Trade Analysis Project model v7, which is an equilibrium CGE model of global trade flows.

A reference workflow is given in: https://github.com/jameel-institute/epi-econ-shocks and in @../epi-econ-shocks/

## Style and conventions

- Use British English in all documentation and comments ("modelling", "behaviour", etc.)
- Prefer explicit types over duck typing for the core simulation types
- Document all public functions with docstrings
- Always add a new plan when new functionality is requested.
- New plans should be added under @plans/
- Always add tests when adding new functionality.
- Tests should added under @test.
- Create a new test file for each feature.
- Do not run tests locally.
- Do not commit any files unless requested.
- Always credit Claude with the model version when a commit is requested.
- Always add a summary to the changelog in @CHANGELOG.md when making edits.
