import MathOptInterface as MOI

struct FlatModel
    n::Int
    m_nlp::Int
    m_aff::Int
    m::Int

    x_l::Vector{Float64}
    x_u::Vector{Float64}
    x0::Vector{Float64}
    var_types::Vector{Cint}   # 0 cont, 1 int, 2 bin

    g_l_nlp::Vector{Float64}
    g_u_nlp::Vector{Float64}
    jac_i_nlp::Vector{Cint}
    jac_j_nlp::Vector{Cint}

    jac_i::Vector{Cint}
    jac_j::Vector{Cint}

    A_i::Vector{Cint}
    A_j::Vector{Cint}
    A_v::Vector{Float64}
    g_l_aff::Vector{Float64}
    g_u_aff::Vector{Float64}

    has_nlp_objective::Bool
    evaluator::Union{Nothing,MOI.AbstractNLPEvaluator}

    obj_aff_terms::Vector{Tuple{Int,Float64}}   # (1-based col, coeff)
    obj_constant::Float64
    has_affine_objective::Bool
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
    # variables
    vars = MOI.get(model, MOI.ListOfVariableIndices())
    n = length(vars)
    var_to_col = Dict(vi => i for (i, vi) in enumerate(vars))  # 1-based

    # -------------------------
    # NONLINEAR PART
    # -------------------------
    nlp_info = _extract_nlp_representation(model, vars)

    evaluator = nlp_info.evaluator
    m_nlp = nlp_info.m_nlp
    g_l_nlp = nlp_info.g_l_nlp
    g_u_nlp = nlp_info.g_u_nlp
    jac_i_nlp = nlp_info.jac_i_nlp
    jac_j_nlp = nlp_info.jac_j_nlp
    has_nlp_objective = nlp_info.has_nlp_objective

    @assert length(jac_i_nlp) == length(jac_j_nlp)
    @assert all(0 .<= jac_j_nlp .< n) "Invalid Jacobian column index"

    # -------------------------
    # AFFINE CONSTRAINTS
    # -------------------------
    aff_le = MOI.get(
        model,
        MOI.ListOfConstraintIndices{
            MOI.ScalarAffineFunction{Float64},
            MOI.LessThan{Float64},
        }(),
    )

    aff_ge = MOI.get(
        model,
        MOI.ListOfConstraintIndices{
            MOI.ScalarAffineFunction{Float64},
            MOI.GreaterThan{Float64},
        }(),
    )

    aff_eq = MOI.get(
        model,
        MOI.ListOfConstraintIndices{
            MOI.ScalarAffineFunction{Float64},
            MOI.EqualTo{Float64},
        }(),
    )

    cis = Any[]
    append!(cis, aff_le)
    append!(cis, aff_ge)
    append!(cis, aff_eq)

    m_aff = length(cis)

    A_i = Cint[]
    A_j = Cint[]
    A_v = Float64[]

    g_l_aff = Float64[]
    g_u_aff = Float64[]

    for (row, ci) in enumerate(cis)
        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        s = MOI.get(model, MOI.ConstraintSet(), ci)

        for t in f.terms
            col = var_to_col[t.variable] - 1
            push!(A_i, Cint(row - 1))
            push!(A_j, Cint(col))
            push!(A_v, t.coefficient)
        end

        if s isa MOI.GreaterThan{Float64}
            push!(g_l_aff, s.lower - f.constant)
            push!(g_u_aff, Inf)
        elseif s isa MOI.LessThan{Float64}
            push!(g_l_aff, -Inf)
            push!(g_u_aff, s.upper - f.constant)
        elseif s isa MOI.EqualTo{Float64}
            val = s.value - f.constant
            push!(g_l_aff, val)
            push!(g_u_aff, val)
        else
            error("Unsupported affine constraint set: $s")
        end
    end

    # -------------------------
    # COMBINED JACOBIAN STRUCTURE
    # -------------------------
    jac_i = copy(jac_i_nlp)
    jac_j = copy(jac_j_nlp)
    for k in eachindex(A_i)
        push!(jac_i, Cint(A_i[k] + m_nlp))  # affine rows after NLP rows
        push!(jac_j, A_j[k])
    end

    @assert length(jac_i) == length(jac_j)

    # -------------------------
    # OBJECTIVE
    # -------------------------
    obj_aff_terms = Tuple{Int,Float64}[]
    obj_constant = 0.0
    has_affine_objective = false

    obj_type = MOI.get(model, MOI.ObjectiveFunctionType())

    if has_nlp_objective || obj_type == MOI.ScalarNonlinearFunction
        has_affine_objective = false
        empty!(obj_aff_terms)
        obj_constant = 0.0
    elseif obj_type == MOI.ScalarAffineFunction{Float64}
        f = MOI.get(model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
        has_affine_objective = true
        obj_constant = f.constant
        for t in f.terms
            push!(obj_aff_terms, (var_to_col[t.variable], t.coefficient))
        end
    elseif obj_type == MOI.VariableIndex
        v = MOI.get(model, MOI.ObjectiveFunction{MOI.VariableIndex}())
        has_affine_objective = true
        obj_constant = 0.0
        push!(obj_aff_terms, (var_to_col[v], 1.0))
    end

    # -------------------------
    # VARIABLES
    # -------------------------
    x_l, x_u, x0, var_types = _var_bounds(model, vars)

    @assert length(x_l) == n
    @assert length(x_u) == n
    @assert length(x0) == n
    @assert length(var_types) == n

    # total constraints
    m = m_nlp + m_aff

    @assert length(g_l_nlp) == m_nlp
    @assert length(g_u_nlp) == m_nlp
    @assert length(g_l_aff) == m_aff
    @assert length(g_u_aff) == m_aff

    return FlatModel(
        n,
        m_nlp,
        m_aff,
        m,
        x_l,
        x_u,
        x0,
        var_types,
        g_l_nlp,
        g_u_nlp,
        jac_i_nlp,
        jac_j_nlp,
        jac_i,
        jac_j,
        A_i,
        A_j,
        A_v,
        g_l_aff,
        g_u_aff,
        has_nlp_objective,
        evaluator,
        obj_aff_terms,
        obj_constant,
        has_affine_objective,
    )
end