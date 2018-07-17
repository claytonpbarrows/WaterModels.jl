export run_feasibility

function run_feasibility(file, model_constructor, solver; kwargs...)
    return run_generic_model(file, model_constructor, solver, post_feasibility; kwargs...)
end

function post_feasibility(wm::GenericWaterModel; kwargs...)
    num_separators = wm.setting["num_separators"]

    variable_flow(wm)
    variable_head(wm)
    variable_head_difference(wm)
    variable_flow_direction(wm)

    for i in [collect(ids(wm, :junctions)); collect(ids(wm, :reservoirs))]
        constraint_flow_conservation(wm, i)
        constraint_potential_flow_coupling(wm, i, num_separators)
    end

    for a in collect(ids(wm, :pipes))
        constraint_define_gamma(wm, a)
        constraint_bidirectional_flow(wm, a)
    end

    # Uncomment this to ensure a physically-feasible solution.
    # objective_minimize_gamma(wm)
end