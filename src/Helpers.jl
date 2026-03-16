
module Helpers

export get_eu_states, cluster_regions, cluster_named_array, cluster_commodities,
       cluster_endowments

using NamedArrays

function get_eu_states()::Vector{String}
    return ["aut", "bel", "bgr", "hrv", "cyp", "cze", "dnk", "est",
        "fin", "fra", "deu", "grc", "hun", "irl", "ita", "lva", "ltu",
        "lux", "mlt", "nld", "pol", "prt", "rou", "svk", "svn", "esp",
        "swe"]
end

"""
    cluster_named_array(x::NamedArray, preserve::Union{String, Vector{String}};
        fill_value::String = "XYZ",
        groups::Union{Nothing, Dict{String, <:AbstractVector{String}}, NamedTuple} = nothing)

Aggregate elements in a NamedArray by preserving specified indices and filling
    the rest with a specified value. Optionally group non-preserved elements into named categories.

# Arguments
- `x::NamedArray`: Input NamedArray to cluster.
- `preserve::Union{String, Vector{String}}`: Index or indices to keep unchanged.
- `fill_value::String`: Value to assign to non-preserved elements. Defaults to "XYZ".
- `groups::Union{Nothing, Dict, NamedTuple}`: Optional mapping of group names to member lists.
    If provided, members of each group are set to the group name instead of `fill_value`.
    Can be a `Dict{String, Vector{String}}` or a `NamedTuple` mapping group names to their members.
    Defaults to `nothing` (no grouping, all non-preserved elements get `fill_value`).

# Returns
- `NamedArray`: New array with preserved elements unchanged. Non-preserved elements are assigned
    to their group name (if in `groups`) or to `fill_value` otherwise.

# Examples
```julia
# Basic clustering without groups
x = NamedArray(["a", "b", "c", "d"], [:item])
result = cluster_named_array(x, ["a", "c"]; fill_value = "other")
# result: ["a", "other", "c", "other"]

# Clustering with Dict groups
groups = Dict("group1" => ["b"], "group2" => ["d"])
result = cluster_named_array(x, ["a", "c"]; fill_value = "other", groups = groups)
# result: ["a", "group1", "c", "group2"]

# Clustering with NamedTuple groups
groups = (group1 = ["b"], group2 = ["d"])
result = cluster_named_array(x, ["a", "c"]; fill_value = "other", groups = groups)
# result: ["a", "group1", "c", "group2"]
```
"""
function cluster_named_array(x::NamedArray,
        preserve::Union{String, Vector{String}};
        fill_value::String = "XYZ",
        groups::Union{Nothing, Dict{String, <:AbstractVector{String}}, NamedTuple} = nothing)
    y = deepcopy(x[preserve])
    z = deepcopy(x)

    z .= fill_value
    z[preserve] .= y

    if !isnothing(groups)
        for (name, members) in pairs(groups)
            z[collect(members)] .= string(name)
        end
    end

    return z
end

"""
    cluster_regions(regions::NamedArray, preserve::Union{String, Vector{String}}
         = ["gbr", "usa", "chn", "eur"]; fill_value::String = "row")::NamedArray

Aggregate regions in a NamedArray by clustering non-preserved regions into a
"row" (rest of world) category.

# Arguments
- `regions::NamedArray`: Input array of region codes.
- `preserve::Union{String, Vector{String}}`: Region(s) to keep separate from
    aggregation. Defaults to ["gbr", "usa", "chn", "eur"].
  - If "eur" is specified, it is expanded to all EU member states (via `get_eu_states()`)
    and removed from the preserve list, then uses the `groups` mechanism in `cluster_named_array`
    to map individual EU member states to "eur".
- `fill_value::String`: Value to assign to non-preserved, non-grouped regions.
    Defaults to "row" (rest of world).

# Returns
- `NamedArray`: New array with preserved regions unchanged and all other regions
    aggregated into `fill_value`.
  - Individual EU member states are mapped to "eur" if "eur" was in the
    preserve list.

# Example
```julia
regions = NamedArray(["gbr", "usa", "fra", "ind"], [:region])
result = cluster_regions(regions, ["gbr", "usa"])
# result: ["gbr", "usa", "row", "row"]
```
"""
function cluster_regions(regions::NamedArray,
        preserve::Union{String, Vector{String}} =
        ["gbr", "usa", "chn", "eur"];
        fill_value::String = "row")::NamedArray
    if length(preserve) > 1 && any(occursin.("eur", preserve))
        # more verbose but less brittle than providing a numeric range
        eu_states = get_eu_states()
        filter!(x -> x ≠ "eur", preserve)
        groups = Dict("eur" => eu_states)
    else
        groups = nothing
    end

    return cluster_named_array(regions, preserve; fill_value = "row", groups = groups)
end

"""
    cluster_commodities(commodities::NamedArray)::NamedArray

Aggregate commodities in a NamedArray by clustering into major commodity groups.

# Arguments
- `commodities::NamedArray`: Input array of commodity codes.

# Returns
- `NamedArray`: New array with commodities clustered into groups: crops, animals, extract,
  processed food, manuf (manufacturing), and svces (services).

# Example
```julia
commodities = NamedArray([1:65;], [:commodity])
result = cluster_commodities(commodities)
```
"""
function cluster_commodities(commodities::NamedArray)::NamedArray
    comm_agg = deepcopy(commodities)

    # Note: not looking too closely into commodities aggregation
    comm_agg[1:8] .= "crops"
    comm_agg[9:12] .= "animals"
    comm_agg[13:18] .= "extract"
    comm_agg[19:26] .= "processed food"
    comm_agg[27:45] .= "manuf"
    comm_agg[46:65] .= "svces"

    return comm_agg
end

"""
    cluster_endowments(endowm::NamedArray)::NamedArray

Aggregate endowments in a NamedArray by clustering into major factor groups.

# Arguments
- `endowm::NamedArray`: Input array of endowment codes.

# Returns
- `NamedArray`: New array with endowments clustered into groups: land, skilled labor,
  unskilled labor, capital, and other.

# Example
```julia
endowments = NamedArray([:land, :skilled, :unskilled, :capital, :other], [:endowment])
result = cluster_endowments(endowments)
```
"""
function cluster_endowments(endowm::NamedArray)::NamedArray
    endow_agg = deepcopy(endowm)

    # Note: taken from GTAP example
    endow_agg[:] .= "other"
    endow_agg[1:1] .= "land"
    endow_agg[[2, 5]] .= "skilled labor"
    endow_agg[[3, 4, 6]] .= "unskilled labor"
    endow_agg["capital"] = "capital"

    return endow_agg
end

end
