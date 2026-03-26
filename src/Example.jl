
module Example

export shock_gtap_example, get_example_model

import GlobalTradeAnalysisProjectModelV7 as GTAP

import ..shock_gtap
import ..ParameterShock

"""
    get_example_model()

Get a simple example model using example data from GlobalTradeAnalysisProject.jl.
"""
function get_example_model()::GTAP.model_container_struct
    (; hData, hParameters, hSets) = GTAP.get_sample_data()
    mc = GTAP.generate_initial_model(hSets = hSets, hData = hData, hParameters = hParameters)

    start_data = deepcopy(mc.data)
    (; fixed_calibration,
        data_calibration) = GTAP.generate_calibration_inputs(mc, start_data)

    mc.data = deepcopy(data_calibration)
    mc.fixed = deepcopy(fixed_calibration)

    GTAP.run_model!(mc)

    return mc
end

"""
    shock_gtap_example(model::GTAP.model_container_struct, shocks::Vector{ParameterShock})

Run an example of passing a (labour supply) shock to a GTAP model, using the
    example dataset provided in `GlobalTradeAnalysisProjectModelV7.jl`.

This is a convenience function that delegates to `shock_gtap` but using
    example data. This function exists because the full GTAP data is used
    under license and cannot be shared online.
"""
function shock_gtap_example(model::GTAP.model_container_struct,
        shocks::Vector{ParameterShock})
    return shock_gtap(model, shocks)
end

end
