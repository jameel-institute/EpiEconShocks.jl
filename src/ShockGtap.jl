
export shock_gtap

using GlobalTradeAnalysisProjectModelV7
using HeaderArrayFile
using NamedArrays

"""
    shock_gtap(nquarters::Int = 8, shock_multipliers::Vector{Float64} = repeat([0.5], nquarters))
Run a sequence of labour supply shocks in the GTAP model and examine the
resulting changes in GDP/income and expenditure.

Code taken from the example provided in the documentation of
GlobalTradeAnalysisProjectModelV7.jl, with some modifications to apply a
sequence of shocks and save the results.

# Arguments
- `nquarters`: Number of quarters to simulate (default: 8)
- `shock_multipliers`: Vector of proportional multipliers to apply to the
  labour endowment for each quarter (default: 50% reduction for all quarters)

# Returns
A named tuple containing:
- `y_by_q`: Named array of GDP/income by region and quarter;
- `ev_by_q`: Named array of expenditure change by region and quarter.

# Examples
```julia
results = shock_gtap(8)
```
"""
function shock_gtap(
        nquarters::Int = 8, shock_multipliers::Vector{Float64} = repeat([0.5], nquarters))
    # Get the sample data
    (; hData, hParameters, hSets) = get_sample_data()

    # Produce initial uncalibrated model using the GTAP data
    mc = generate_initial_model(hSets = hSets, hData = hData, hParameters = hParameters)

    # Keep the start data for calibration---the value flows are the correct ones
    start_data = deepcopy(mc.data)

    # Get the required inputs for calibration by providing the target values in start_data
    (; fixed_calibration, data_calibration) = generate_calibration_inputs(mc, start_data)

    # Keep the default closure (fixed) for later
    fixed_default = deepcopy(mc.fixed)

    # Load the calibration data and closure 
    mc.data = deepcopy(data_calibration)
    mc.fixed = deepcopy(fixed_calibration)

    run_model!(mc)

    # Save the calibrated data---this is the starting point for all simulation
    calibrated_data = deepcopy(mc.data)

    # NOTE: this model has no real representation of time; the shocks
    # occur at some t timepoints that could represent any time interval
    quarters = 1:nquarters
    regions = mc.sets["reg"]

    # NOTE: example data only has skilled or unskilled labour
    labour_name = ["skilled labor", "unskilled labor"]

    # make deep copies as calibrated data is modified in place
    # NOTE: example data has NaNs - unclear whether this is expected or
    # these should be replaced with zeros
    # NOTE: "qe" appears to be endowment per region, "qes" is the same per sector
    # qes has one more dimension than qe to accommodate this
    base_qe = deepcopy(calibrated_data["qe"])   # aggregate factor endowments
    base_qes = deepcopy(calibrated_data["qes"]) # detailed per-activity factor (optional)

    # prepare storage for results
    # NOTE: no real reason to use NamedArray other than user convenience IMO
    y_by_q = NamedArray(
        zeros(length(regions), length(quarters)), (regions, collect(quarters)))
    wage_by_q = NamedArray(
        zeros(length(regions), length(quarters)), (regions, collect(quarters)))
    ev_by_q = NamedArray(
        zeros(length(regions), length(quarters)), (regions, collect(quarters)))

    for q in quarters
        # apply shock to aggregate labour endowment (exogenous)
        # NOTE: must re-use initial value as mc.data is modified in place
        mc.data["qe"][labour_name, :] .= base_qe[labour_name, :] .* shock_multipliers[q]

        run_model!(mc)

        # save outputs
        y_by_q[:, q] .= mc.data["y"]  # GDP/income
        ev_by_q[:, q] .= calculate_expenditure(
            sets = mc.sets,
            data0 = calibrated_data,
            data1 = mc.data,
            parameters = mc.parameters
        ) .- calibrated_data["y"]
    end

    # examine gdp/income and expenditure
    # NOTE: I don't understand the specifics of the internal calculations
    # or the correct interpretation

    return (y_by_q = y_by_q, ev_by_q = ev_by_q)
end
