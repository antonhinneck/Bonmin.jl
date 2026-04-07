import MathOptInterface as MOI

mutable struct CallbackState
    evaluator::Union{Nothing,MOI.AbstractNLPEvaluator}

    x::Vector{Float64}

    # nonlinear constraints / jacobian
    g_nlp::Vector{Float64}
    jac_nlp::Vector{Float64}

    # affine constraints (sparse triplets, 0-based rows/cols)
    A_i::Vector{Cint}
    A_j::Vector{Cint}
    A_v::Vector{Float64}

    m_nlp::Int
    m_aff::Int

    # objective
    obj_aff_terms::Vector{Tuple{Int,Float64}}   # 1-based col, coeff
    obj_constant::Float64
    has_affine_objective::Bool
    has_nlp_objective::Bool

    # gradient buffer
    grad::Vector{Float64}
end

function make_state(flat::FlatModel)
    if flat.evaluator !== nothing
        MOI.initialize(flat.evaluator, [:Grad, :Jac])
    end

    return CallbackState(
        flat.evaluator,
        zeros(flat.n),

        zeros(flat.m_nlp),
        zeros(length(flat.jac_i_nlp)),

        flat.A_i,
        flat.A_j,
        flat.A_v,

        flat.m_nlp,
        flat.m_aff,

        flat.obj_aff_terms,
        flat.obj_constant,
        flat.has_affine_objective,
        flat.has_nlp_objective,

        zeros(flat.n),
    )
end

function _copy_x!(dest::Vector{Float64}, xptr::Ptr{Cdouble}, n::Cint)
    unsafe_copyto!(pointer(dest), xptr, Int(n))
    return
end

function jl_eval_f(user_data::Ptr{Cvoid}, xptr::Ptr{Cdouble}, n::Cint)::Cdouble
    st = unsafe_pointer_to_objref(user_data)::CallbackState
    _copy_x!(st.x, xptr, n)

    obj = 0.0

    if st.has_nlp_objective && st.evaluator !== nothing
        obj += MOI.eval_objective(st.evaluator, st.x)
    end

    if st.has_affine_objective
        for (col, coef) in st.obj_aff_terms
            obj += coef * st.x[col]
        end
        obj += st.obj_constant
    end

    return obj
end

function jl_eval_grad_f(
    user_data::Ptr{Cvoid},
    xptr::Ptr{Cdouble},
    n::Cint,
    gradptr::Ptr{Cdouble},
)::Cvoid
    st = unsafe_pointer_to_objref(user_data)::CallbackState
    _copy_x!(st.x, xptr, n)

    fill!(st.grad, 0.0)

    if st.has_nlp_objective && st.evaluator !== nothing
        MOI.eval_objective_gradient(st.evaluator, st.grad, st.x)
    end

    if st.has_affine_objective
        for (col, coef) in st.obj_aff_terms
            st.grad[col] += coef
        end
    end

    unsafe_copyto!(gradptr, pointer(st.grad), Int(n))
    return
end

function jl_eval_g(
    user_data::Ptr{Cvoid},
    xptr::Ptr{Cdouble},
    n::Cint,
    gptr::Ptr{Cdouble},
    m::Cint,
)::Cvoid
    st = unsafe_pointer_to_objref(user_data)::CallbackState
    _copy_x!(st.x, xptr, n)

    # NLP part
    if st.m_nlp > 0 && st.evaluator !== nothing
        fill!(st.g_nlp, 0.0)
        MOI.eval_constraint(st.evaluator, st.g_nlp, st.x)
        unsafe_copyto!(gptr, pointer(st.g_nlp), Int(st.m_nlp))
    end

    # affine part
    g_aff_ptr = gptr + st.m_nlp

    for i in 1:st.m_aff
        unsafe_store!(g_aff_ptr + (i - 1), 0.0)
    end

    for k in eachindex(st.A_i)
        row = Int(st.A_i[k])          # 0-based
        col = Int(st.A_j[k]) + 1      # Julia 1-based
        current = unsafe_load(g_aff_ptr + row)
        unsafe_store!(g_aff_ptr + row, current + st.A_v[k] * st.x[col])
    end

    @assert st.m_nlp + st.m_aff == m
    return
end

function jl_eval_jac_g(
    user_data::Ptr{Cvoid},
    xptr::Ptr{Cdouble},
    n::Cint,
    valuesptr::Ptr{Cdouble},
    nnz::Cint,
)::Cvoid
    st = unsafe_pointer_to_objref(user_data)::CallbackState
    _copy_x!(st.x, xptr, n)

    idx = 1

    # NLP Jacobian values in EXACTLY the same order as MOI.jacobian_structure
    if st.m_nlp > 0 && st.evaluator !== nothing
        fill!(st.jac_nlp, 0.0)
        MOI.eval_constraint_jacobian(st.evaluator, st.jac_nlp, st.x)

        for v in st.jac_nlp
            unsafe_store!(valuesptr + (idx - 1), v)
            idx += 1
        end
    end

    # affine Jacobian values
    for v in st.A_v
        unsafe_store!(valuesptr + (idx - 1), v)
        idx += 1
    end

    @assert idx - 1 == nnz
    return
end