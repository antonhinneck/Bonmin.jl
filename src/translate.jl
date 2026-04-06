import MathOptInterface as MOI

struct FlatModel
    n::Int
    m::Int
    x_l::Vector{Float64}
    x_u::Vector{Float64}
    x0::Vector{Float64}
    var_types::Vector{Cint}   # 0 cont, 1 int, 2 bin
    g_l::Vector{Float64}
    g_u::Vector{Float64}
    jac_i::Vector{Cint}
    jac_j::Vector{Cint}
    has_nlp_objective::Bool
    evaluator::MOI.AbstractNLPEvaluator
end

function _var_bounds(model, vars)
    n = length(vars)
    xl = fill(-Inf, n)
    xu = fill( Inf, n)
    x0 = zeros(n)
    vtype = fill(Cint(0), n)

    for (k, vi) in enumerate(vars)
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.LessThan{Float64}}())
            f = MOI.get(model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model, MOI.ConstraintSet(), ci)
            f == vi && (xu[k] = min(xu[k], s.upper))
        end
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.GreaterThan{Float64}}())
            f = MOI.get(model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model, MOI.ConstraintSet(), ci)
            f == vi && (xl[k] = max(xl[k], s.lower))
        end
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.Interval{Float64}}())
            f = MOI.get(model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model, MOI.ConstraintSet(), ci)
            if f == vi
                xl[k] = max(xl[k], s.lower)
                xu[k] = min(xu[k], s.upper)
            end
        end
        if MOI.supports(model, MOI.VariablePrimalStart(), MOI.VariableIndex)
            val = MOI.get(model, MOI.VariablePrimalStart(), vi)
            val !== nothing && (x0[k] = val)
        end
        # integrality
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.Integer}())
            MOI.get(model, MOI.ConstraintFunction(), ci) == vi && (vtype[k] = 1)
        end
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.ZeroOne}())
            MOI.get(model, MOI.ConstraintFunction(), ci) == vi && begin
                vtype[k] = 2
                xl[k] = max(xl[k], 0.0)
                xu[k] = min(xu[k], 1.0)
            end
        end
    end
    return xl, xu, x0, vtype
end

function build_flat_model(model::MOI.ModelLike)
    vars = MOI.get(model, MOI.ListOfVariableIndices())
    n = length(vars)

    nlp = MOI.get(model, MOI.NLPBlock())
    evaluator = nlp.evaluator
    MOI.initialize(evaluator, [:Grad, :Jac])

    jac_struct = MOI.jacobian_structure(evaluator)
    jac_i = Cint[i - 1 for (i, _) in jac_struct]  # C-style for Bonmin
    jac_j = Cint[j - 1 for (_, j) in jac_struct]

    m = length(nlp.constraint_bounds)
    g_l = [b.lower for b in nlp.constraint_bounds]
    g_u = [b.upper for b in nlp.constraint_bounds]

    x_l, x_u, x0, var_types = _var_bounds(model, vars)

    return FlatModel(
        n, m, x_l, x_u, x0, var_types,
        g_l, g_u, jac_i, jac_j,
        nlp.has_objective,
        evaluator,
    )
end