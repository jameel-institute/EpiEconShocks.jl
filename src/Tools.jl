
module Tools

export is_npi_active

"""
    is_npi_active(time::Vector{Float64}, bounds::Vector{Tuple{Float64, Float64}})::Vector{Float64}

Check whether each timepoint in `time` falls within any of the specified bounds.

For each timepoint, returns 1.0 if it falls within at least one bounds interval, 0.0 otherwise.

# Arguments
- `time::Vector{Float64}`: vector of timepoints to check
- `bounds::Vector{Tuple{Float64, Float64}}`: vector of (lower, upper) bound pairs

# Returns
- `Vector{Float64}`: vector of indicators (1.0 or 0.0) with length matching `time`

# Raises
- `ArgumentError`: if `bounds` is empty or if any bound has lower > upper
"""
function is_npi_active(time::Vector{Float64}, bounds::Vector{Tuple{
        Float64, Float64}})::Vector{Float64}
    if isempty(bounds)
        throw(ArgumentError("`bounds` cannot be empty"))
    end

    for (i, (t1, t2)) in enumerate(bounds)
        if t1 > t2
            throw(ArgumentError("bounds[$i]: lower bound ($t1) must be ≤ upper bound ($t2)"))
        end
    end

    max_time = maximum(time)
    max_bound = maximum([t2 for (t1, t2) in bounds])

    if max_time > 0 && max_bound > 0
        magnitude_diff = abs(log10(max_bound) - log10(max_time))
        if magnitude_diff >= 3
            @warn "Bounds and time vector differ by approximately $(round(Int, magnitude_diff)) orders of magnitude (time max: $max_time, bounds max: $max_bound)"
        end
    end

    return float.([any([t1 <= t <= t2 for (t1, t2) in bounds]) for t in time])
end

end
