struct FlatNLPInfo
    evaluator
    m_nlp::Int
    g_l_nlp::Vector{Float64}
    g_u_nlp::Vector{Float64}
    jac_i_nlp::Vector{Cint}
    jac_j_nlp::Vector{Cint}
    has_nlp_objective::Bool
end

_empty_nlp_info() = FlatNLPInfo(
    nothing, 0, Float64[], Float64[], Cint[], Cint[], false
)

function _nlp_info_from_nlpblock(nlp)
    evaluator = nlp.evaluator
    MOI.initialize(evaluator, [:Grad, :Jac])

    jac_struct = collect(MOI.jacobian_structure(evaluator))
    jac_i_nlp = Cint[i - 1 for (i, _) in jac_struct]
    jac_j_nlp = Cint[j - 1 for (_, j) in jac_struct]

    m_nlp = length(nlp.constraint_bounds)
    g_l_nlp = [b.lower for b in nlp.constraint_bounds]
    g_u_nlp = [b.upper for b in nlp.constraint_bounds]

    return FlatNLPInfo(
        evaluator,
        m_nlp,
        g_l_nlp,
        g_u_nlp,
        jac_i_nlp,
        jac_j_nlp,
        nlp.has_objective,
    )
end

function _has_scalar_nonlinear_constraints(model)
    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        if F == MOI.ScalarNonlinearFunction &&
           S <: Union{
               MOI.LessThan{Float64},
               MOI.GreaterThan{Float64},
               MOI.EqualTo{Float64},
               MOI.Interval{Float64},
           }
            return true
        end
    end
    return false
end

function _nlp_info_from_scalar_nonlinear(model, vars)
    nlp_model = MOI.Nonlinear.Model()

    sets = (
        MOI.LessThan{Float64},
        MOI.GreaterThan{Float64},
        MOI.EqualTo{Float64},
        MOI.Interval{Float64},
    )

    for S in sets
        cis = MOI.get(
            model,
            MOI.ListOfConstraintIndices{MOI.ScalarNonlinearFunction,S}(),
        )
        for ci in cis
            f = MOI.get(model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model, MOI.ConstraintSet(), ci)
            MOI.Nonlinear.add_constraint(nlp_model, f, s)
        end
    end

    has_nlp_objective = false
    obj_type = MOI.get(model, MOI.ObjectiveFunctionType())
    if obj_type == MOI.ScalarNonlinearFunction
        f = MOI.get(model, MOI.ObjectiveFunction{MOI.ScalarNonlinearFunction}())
        MOI.Nonlinear.set_objective(nlp_model, f)
        has_nlp_objective = true
    end

    evaluator = MOI.Nonlinear.Evaluator(
        nlp_model,
        MOI.Nonlinear.SparseReverseMode(),
        vars,
    )
    MOI.initialize(evaluator, [:Grad, :Jac])

    jac_struct = collect(MOI.jacobian_structure(evaluator))
    jac_i_nlp = Cint[i - 1 for (i, _) in jac_struct]
    jac_j_nlp = Cint[j - 1 for (_, j) in jac_struct]

    # Reconstruct bounds in the same order we inserted constraints
    g_l_nlp = Float64[]
    g_u_nlp = Float64[]

    for S in sets
        cis = MOI.get(
            model,
            MOI.ListOfConstraintIndices{MOI.ScalarNonlinearFunction,S}(),
        )
        for ci in cis
            s = MOI.get(model, MOI.ConstraintSet(), ci)
            if s isa MOI.GreaterThan{Float64}
                push!(g_l_nlp, s.lower)
                push!(g_u_nlp, Inf)
            elseif s isa MOI.LessThan{Float64}
                push!(g_l_nlp, -Inf)
                push!(g_u_nlp, s.upper)
            elseif s isa MOI.EqualTo{Float64}
                push!(g_l_nlp, s.value)
                push!(g_u_nlp, s.value)
            elseif s isa MOI.Interval{Float64}
                push!(g_l_nlp, s.lower)
                push!(g_u_nlp, s.upper)
            else
                error("Unsupported nonlinear constraint set: $s")
            end
        end
    end

    m_nlp = length(g_l_nlp)

    return FlatNLPInfo(
        evaluator,
        m_nlp,
        g_l_nlp,
        g_u_nlp,
        jac_i_nlp,
        jac_j_nlp,
        has_nlp_objective,
    )
end

function _extract_nlp_representation(model, vars)
    has_nl_cons = _has_scalar_nonlinear_constraints(model)
    has_nl_obj =
        MOI.get(model, MOI.ObjectiveFunctionType()) == MOI.ScalarNonlinearFunction

    if has_nl_cons || has_nl_obj
        return _nlp_info_from_scalar_nonlinear(model, vars)
    end

    nlp = MOI.get(model, MOI.NLPBlock())
    if nlp !== nothing && (length(nlp.constraint_bounds) > 0 || nlp.has_objective)
        return _nlp_info_from_nlpblock(nlp)
    end

    return _empty_nlp_info()
end