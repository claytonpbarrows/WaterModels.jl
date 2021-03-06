########################################################################
# This file defines commonly-used variables for water systems models.
########################################################################

function variable_head(wm::GenericWaterModel, n_n::Int)
    # Get indices for all network nodes.
    nodes = [collect(ids(wm, n_n, :junctions));
             collect(ids(wm, n_n, :reservoirs))]

    # Get the bounds associated with heads at nodes.
    lbs, ubs = calc_head_bounds(wm, n_n)

    # Initialize variables associated with head.
    wm.var[:nw][n_n][:h] = @variable(wm.model, [i in nodes], lowerbound = lbs[i],
                                     upperbound = ubs[i], start = ubs[i],
                                     category = :Cont, basename = "h_$(n_n)")
end

function variable_head_difference(wm::GenericWaterModel, n_n::Int)
    # Get indices for all network arcs.
    arcs = collect(ids(wm, n_n, :connection))

    # Get the bounds for the head difference variables.
    lbs, ubs = calc_head_difference_bounds(wm, n_n)

    # Initialize variables associated with negative head differences.
    wm.var[:nw][n_n][:dhn] = @variable(wm.model, [a in arcs], lowerbound = 0.0,
                                       upperbound = abs(lbs[a]), start = abs(lbs[a]),
                                       category = :Cont, basename = "dhn_$(n_n)")

    # Initialize variables associated with positive head differences.
    wm.var[:nw][n_n][:dhp] = @variable(wm.model, [a in arcs], lowerbound = 0.0,
                                       upperbound = abs(ubs[a]), start = abs(ubs[a]),
                                       category = :Cont, basename = "dhp_$(n_n)")
end

function variable_flow_direction(wm::GenericWaterModel, n_n::Int)
    # Get indices for all network arcs.
    arcs = collect(ids(wm, n_n, :connection))

    # Initialize variables associated with flow direction. If this variable is
    # equal to one, the flow direction is from i to j. If it is equal to zero,
    # the flow direction is from j to i.
    wm.var[:nw][n_n][:dir] = @variable(wm.model, [a in arcs], start = 1,
                                       category = :Bin, basename = "dir_$(n_n)")

    # Fix direction bounds if they can be fixed.
    dh_lbs, dh_ubs = calc_head_difference_bounds(wm, n_n)
    for (a, connection) in wm.ref[:nw][n_n][:connection]
        if (dh_lbs[a] >= 0.0)
            setlowerbound(wm.var[:nw][n_n][:dir][a], 1)
            setvalue(wm.var[:nw][n_n][:dir][a], 1)
        elseif (dh_ubs[a] <= 0.0)
            setupperbound(wm.var[:nw][n_n][:dir][a], 0)
            setvalue(wm.var[:nw][n_n][:dir][a], 0)
        end
    end
end

function variable_resistance(wm::GenericWaterModel, n_n::Int)
    # Get indices for all network arcs.
    arcs = collect(ids(wm, n_n, :connection))

    # Initialize variables associated with flow direction. If this variable is
    # equal to one, the flow direction is from i to j. If it is equal to zero,
    # the flow direction is from j to i.
    wm.var[:nw][n_n][:xr] = Dict{Int, Array{Variable, 1}}()

    for (a, connection) in wm.ref[:nw][n_n][:connection]
        R_a = wm.ref[:nw][n_n][:resistance][a]

        wm.var[:nw][n_n][:xr][a] = @variable(wm.model, [r in 1:length(R_a)],
                                             start = 0, category = :Bin,
                                             basename = "xr_$(n_n)_$(a)")

        setvalue(wm.var[:nw][n_n][:xr][a][1], 1)
    end
end

#function variable_directed_flow(wm::GenericWaterModel, n::Int = wm.cnw) where T <: StandardMINLPForm
#    # Get indices for all network arcs.
#    arcs = collect(ids(wm, n, :connection))
#
#    # Compute sets of resistances.
#    ub_n, ub_p = calc_directed_flow_upper_bounds(wm, n)
#
#    # Initialize directed flow variables. The variables qp correspond to flow
#    # from i to j, and the variables qn correspond to flow from j to i.
#    wm.var[:nw][n][:qp] = Dict{Int, Array{Variable, 1}}()
#    wm.var[:nw][n][:qn] = Dict{Int, Array{Variable, 1}}()
#
#    for (a, connection) in wm.ref[:nw][n][:connection]
#        R_a = wm.ref[:nw][n][:resistance][a]
#
#        # Initialize variables associated with flow from i to j.
#        wm.var[:nw][n][:qp][a] = @variable(wm.model, [r in 1:length(R_a)],
#                                           lowerbound = 0.0,
#                                           upperbound = ub_p[a][r],
#                                           start = 0.0, category = :Cont,
#                                           basename = "qp_$(n)_$(a)")
#
#        # Initialize flow for the variable with least resistance.
#        setvalue(wm.var[:nw][n][:qp][a][end], ub_p[a][end])
#
#        # Initialize variables associated with flow from j to i.
#        wm.var[:nw][n][:qn][a] = @variable(wm.model, [r in 1:length(R_a)],
#                                           lowerbound = 0.0,
#                                           upperbound = ub_n[a][r],
#                                           start = 0.0, category = :Cont,
#                                           basename = "qn_$(n)_$(a)")
#    end
#end

#function variable_flow(wm::GenericWaterModel, n::Int = wm.cnw)
#    lbs, ubs = calc_flow_bounds(wm.ref[:nw][n][:pipes])
#    wm.var[:nw][n][:q] = @variable(wm.model, [id in keys(wm.ref[:nw][n][:pipes])],
#                                   lowerbound = lbs[id], upperbound = ubs[id],
#                                   basename = "q_$(n)", start = 1.0e-4)
#end
#
#function variable_head_common(wm::GenericWaterModel, n::Int = wm.cnw)
#    lbs, ubs = calc_head_bounds(wm.ref[:nw][n][:junctions], wm.ref[:nw][n][:reservoirs])
#    junction_ids = [key for key in keys(wm.ref[:nw][n][:junctions])]
#    reservoir_ids = [key for key in keys(wm.ref[:nw][n][:reservoirs])]
#    ids = [junction_ids; reservoir_ids]
#
#    # Add the head variables to the model.
#    wm.var[:nw][n][:h] = @variable(wm.model, [i in ids], lowerbound = lbs[i],
#                                   upperbound = ubs[i], basename = "h_$(n)",
#                                   start = ubs[i])
#end
#
#"Variables associated with building pipes."
#function variable_pipe_ne_common(wm::GenericWaterModel, n::Int = wm.cnw)
#    # Set up required data to initialize junction variables.
#    pipe_ids = [key for key in keys(wm.ref[:nw][n][:ne_pipe])]
#    wm.var[:nw][n][:psi] = Dict{Int, Any}()
#    wm.var[:nw][n][:gamma] = Dict{Int, Any}()
#    wm.var[:nw][n][:gamma_sum] = Dict{Int, Any}()
#
#    for (pipe_id, pipe) in wm.ref[:nw][n][:ne_pipe]
#        diameters = [d["diameter"] for d in pipe["diameters"]]
#
#        # Create binary variables associated with whether or not a diameter is used.
#        wm.var[:nw][n][:psi][pipe_id] = @variable(wm.model, [d in diameters], category = :Bin,
#                                                  basename = "psi_$(n)_$(pipe_id)", start = 0)
#        setvalue(wm.var[:nw][n][:psi][pipe_id][diameters[end]], 1)
#
#        # Create a variable that corresponds to the selection of lambda.
#        h_i = wm.var[:nw][n][:h][parse(Int, pipe["node1"])]
#        h_j = wm.var[:nw][n][:h][parse(Int, pipe["node2"])]
#
#        # Get additional data related to the variables.
#        hij_lb = getlowerbound(h_i) - getupperbound(h_j)
#        hij_ub = getupperbound(h_i) - getlowerbound(h_j)
#
#        if pipe["flow_direction"] == POSITIVE
#            hij_lb = max(0.0, hij_lb)
#        elseif pipe["flow_direction"] == NEGATIVE
#            hij_ub = min(0.0, hij_ub)
#        end
#
#        lbs = Dict(d => hij_lb / calc_friction_factor_hw_ne(pipe, d) for d in diameters)
#        ubs = Dict(d => hij_ub / calc_friction_factor_hw_ne(pipe, d) for d in diameters)
#
#        min_gamma, max_gamma = [minimum(collect(values(lbs))), maximum(collect(values(ubs)))]
#        wm.var[:nw][n][:gamma][pipe_id] = @variable(wm.model, [d in diameters],
#                                                    lowerbound = lbs[d], upperbound = ubs[d],
#                                                    start = 0.5 * (ubs[d] + lbs[d]))
#        wm.var[:nw][n][:gamma_sum][pipe_id] = @variable(wm.model, lowerbound = min_gamma,
#                                                        upperbound = max_gamma,
#                                                        start = 0.5 * (min_gamma + max_gamma))
#    end
#end
#
#function variable_objective_ne(wm::GenericWaterModel, n::Int = wm.cnw)
#    wm.var[:nw][n][:objective] = @variable(wm.model, basename = "objective_$(n)",
#                                           lowerbound = 0.0, start = 0.0)
#end
