
module Example

export shock_gtap_example, get_example_model

using GlobalTradeAnalysisProjectModelV7
using NamedArrays
using HeaderArrayFile

"""
    get_example_model()

Get a simple example model using example data from GlobalTradeAnalysisProject.jl.
"""
function get_example_model()::model_container_struct
    (; hData, hParameters, hSets) = get_sample_data()
    mc = generate_initial_model(hSets = hSets, hData = hData, hParameters = hParameters)

    start_data = deepcopy(mc.data)
    (; fixed_calibration, data_calibration) = generate_calibration_inputs(mc, start_data)

    mc.data = deepcopy(data_calibration)
    mc.fixed = deepcopy(fixed_calibration)

    run_model!(mc)

    return mc
end

"""
    shock_gtap_example(model::model_container_struct, labour_scaling::Float64)

Run an example of passing a (labour supply) shock to a GTAP model, using the
    example dataset provided in `GlobalTradeAnalysisProjectModelV7.jl`.
"""
function shock_gtap_example(model::model_container_struct,
        labour_scaling::Float64)
    calibrated_data = deepcopy(model.data)
    regions = model.sets["reg"]
    labour_name = ["skilled labor", "unskilled labor"]

    base_qe = deepcopy(calibrated_data["qe"])

    y_by_q = NamedArray(zeros(length(regions), 1), (regions, [1]))
    ev_by_q = NamedArray(zeros(length(regions), 1), (regions, [1]))

    model.data["qe"][labour_name, :] .= base_qe[labour_name, :] .*
                                        labour_scaling

    run_model!(model)

    y_by_q .= model.data["y"]  # GDP/income
    ev_by_q .= calculate_expenditure(
        sets = model.sets,
        data0 = calibrated_data,
        data1 = model.data,
        parameters = model.parameters
    ) .- calibrated_data["y"]

    return (y_by_q = y_by_q, ev_by_q = ev_by_q)
end

end
