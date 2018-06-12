########################################################################
# This file defines commonly-used constraints for water systems models.
########################################################################

function compute_dw_lambda(ref, id)
    # Diameter assumes original units of millimeters.
    diameter = ref[:pipes][id]["diameter"] / 1000.0

    # Roughness assumes original units of millimeters.
    roughness = ref[:pipes][id]["roughness"] / 1000.0

    # Length assumes original units of meters.
    length = ref[:pipes][id]["length"]

    # Use standard gravitational acceleration on earth.
    g = 9.80665

    # Use the Prandtl-Kármán friction factor.
    f_s = 0.25 / log((roughness / diameter) / 3.71)^2

    # Return lambda.
    return (8.0 * length) / (pi^2 * g * diameter^5) * f_s
end

function compute_hw_lambda(ref, id)
    # Diameter assumes original units of millimeters.
    diameter = ref[:pipes][id]["diameter"] / 1000.0

    # Roughness assumes no units.
    roughness = ref[:pipes][id]["roughness"]

    # Length assumes original units of meters.
    length = ref[:pipes][id]["length"]

    # Return lambda.
    return (10.67 * length) / (roughness^1.852 * diameter^4.87)
end

function constraint_flow_conservation{T}(wm::GenericWaterModel{T}, i, n::Int = wm.cnw)
    # Add the flow conservation constraints for junction nodes.
    out_arcs = collect(keys(filter((id, pipe) -> pipe["node1"] == i, wm.ref[:nw][n][:pipes])))
    out_vars = Array{JuMP.Variable}([wm.var[:nw][n][:q][a] for a in out_arcs])
    in_arcs = collect(keys(filter((id, pipe) -> pipe["node2"] == i, wm.ref[:nw][n][:pipes])))
    in_vars = Array{JuMP.Variable}([wm.var[:nw][n][:q][a] for a in in_arcs])

    # Demands assume original units of liters per second.
    if haskey(wm.ref[:nw][n][:junctions], i)
        demand = 0.001 * wm.ref[:nw][n][:junctions][i]["demand"]
        @constraint(wm.model, sum(in_vars) - sum(out_vars) == demand)
    elseif haskey(wm.ref[:nw][n][:reservoirs], i)
        all_demands = [junction["demand"] for junction in values(wm.ref[:nw][n][:junctions])]
        sum_demand = 0.001 * sum(all_demands)
        @constraint(wm.model, sum(out_vars) - sum(in_vars) >= 0.0)
        @constraint(wm.model, sum(out_vars) - sum(in_vars) <= sum_demand)
    end
end

function constraint_potential_flow_coupling{T}(wm::GenericWaterModel{T}, i, n::Int = wm.cnw)
    # Get the outgoing arcs of the node.
    arcs_from = collect(keys(filter((id, pipe) -> pipe["node1"] == i, wm.ref[:nw][n][:pipes])))

    for a in arcs_from
        # Add the potential-flow coupling constraint.
        gamma = wm.var[:nw][n][:gamma][a]
        q = wm.var[:nw][n][:q][a]
        lambda = compute_hw_lambda(wm.ref[:nw][n], a)
        @NLconstraint(wm.model, gamma == 0.88 * lambda * q^2)
    end
end

function constraint_define_gamma{T}(wm::GenericWaterModel{T}, a, n::Int = wm.cnw)
    # Get source and target nodes corresponding to the arc.
    i = wm.ref[:nw][n][:pipes][a]["node1"]
    j = wm.ref[:nw][n][:pipes][a]["node2"]

    # Collect variables needed for the constraint.
    gamma = wm.var[:nw][n][:gamma][a]
    y_p = wm.var[:nw][n][:yp][a]
    y_n = wm.var[:nw][n][:yn][a]
    h_i = wm.var[:nw][n][:h][i]
    h_j = wm.var[:nw][n][:h][j]

    # Get additional data related to the variables.
    h_i_lb = getlowerbound(h_i)
    h_i_ub = getupperbound(h_i)
    h_j_lb = getlowerbound(h_j)
    h_j_ub = getupperbound(h_j)

    # Add the required constraints.
    @constraint(wm.model, h_j - h_i + (h_i_lb - h_j_ub) * (y_p - y_n + 1) <= gamma)
    @constraint(wm.model, h_i - h_j + (h_i_ub - h_j_lb) * (y_p - y_n - 1) <= gamma)
    @constraint(wm.model, h_j - h_i + (h_i_ub - h_j_lb) * (y_p - y_n + 1) >= gamma)
    @constraint(wm.model, h_i - h_j + (h_i_lb - h_j_ub) * (y_p - y_n - 1) >= gamma)
end

function constraint_bidirectional_flow{T}(wm::GenericWaterModel{T}, a, n::Int = wm.cnw)
    # Get source and target nodes corresponding to the arc.
    i = wm.ref[:nw][n][:pipes][a]["node1"]
    j = wm.ref[:nw][n][:pipes][a]["node2"]

    # Collect variables needed for the constraint.
    q = wm.var[:nw][n][:q][a]
    y_p = wm.var[:nw][n][:yp][a]
    y_n = wm.var[:nw][n][:yn][a]
    h_i = wm.var[:nw][n][:h][i]
    h_j = wm.var[:nw][n][:h][j]

    # Get additional data related to the variables.
    h_i_lb = getlowerbound(h_i)
    h_i_ub = getupperbound(h_i)
    h_j_lb = getlowerbound(h_j)
    h_j_ub = getupperbound(h_j)

    # Add the first set of constraints.
    all_demands = [junction["demand"] for junction in values(wm.ref[:nw][n][:junctions])]
    sum_demand = 0.001 * sum(all_demands)
    @constraint(wm.model, (y_p - 1) * sum_demand <= q)
    @constraint(wm.model, (1 - y_n) * sum_demand >= q)

    # Add the second set of constraints.
    @constraint(wm.model, (1 - y_p) * (h_i_lb - h_j_ub) <= h_i - h_j)
    @constraint(wm.model, (1 - y_n) * (h_i_ub - h_j_lb) >= h_i - h_j)

    # Add the third set of constraints.
    @constraint(wm.model, y_p + y_n == 1)
end
