
module Example

export shock_gtap_example

using GlobalTradeAnalysisProjectModelV7
using NamedArrays
using HeaderArrayFile

"""
    shock_gtap_example(labour_scaling::Float64)

Run an example of passing a (labour supply) shock to a GTAP model, using the
    example dataset provided in `GlobalTradeAnalysisProjectModelV7.jl`.
"""
function shock_gtap_example(labour_scaling::Float64)
    (; hData, hParameters, hSets) = get_sample_data()
    mc = generate_initial_model(hSets = hSets, hData = hData, hParameters = hParameters)

    start_data = deepcopy(mc.data)
    (; fixed_calibration, data_calibration) = generate_calibration_inputs(mc, start_data)

    mc.data = deepcopy(data_calibration)
    mc.fixed = deepcopy(fixed_calibration)

    run_model!(mc)

    calibrated_data = deepcopy(mc.data)
    regions = mc.sets["reg"]
    labour_name = ["skilled labor", "unskilled labor"]

    base_qe = deepcopy(calibrated_data["qe"])

    y_by_q = NamedArray(zeros(length(regions), 1), (regions, [1]))
    ev_by_q = NamedArray(zeros(length(regions), 1), (regions, [1]))

    mc.data["qe"][labour_name, :] .= base_qe[labour_name, :] .*
                                     labour_scaling

    run_model!(mc)

    y_by_q .= mc.data["y"]  # GDP/income
    ev_by_q .= calculate_expenditure(
        sets = mc.sets,
        data0 = calibrated_data,
        data1 = mc.data,
        parameters = mc.parameters
    ) .- calibrated_data["y"]

    return (y_by_q = y_by_q, ev_by_q = ev_by_q)
end

end
