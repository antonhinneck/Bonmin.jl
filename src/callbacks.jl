import MathOptInterface as MOI

mutable struct CallbackState
    evaluator::MOI.AbstractNLPEvaluator
    x::Vector{Float64}
    g::Vector{Float64}
    grad::Vector{Float64}
    jac::Vector{Float64}
    hess::Vector{Float64}
end

function make_state(evaluator, n::Int, m::Int, nnz_jac::Int; nnz_hess::Int = 0)
    MOI.initialize(evaluator, [:Grad, :Jac])
    return CallbackState(
        evaluator,
        zeros(n),
        zeros(m),
        zeros(n),
        zeros(nnz_jac),
        zeros(nnz_hess),
    )
end

function _copy_x!(dest::Vector{Float64}, xptr::Ptr{Cdouble}, n::Cint)
    unsafe_copyto!(pointer(dest), xptr, Int(n))
    return
end

function jl_eval_f(user_data::Ptr{Cvoid}, xptr::Ptr{Cdouble}, n::Cint)::Cdouble
    st = unsafe_pointer_to_objref(user_data)::CallbackState
    _copy_x!(st.x, xptr, n)
    return MOI.eval_objective(st.evaluator, st.x)
end

function jl_eval_grad_f(user_data::Ptr{Cvoid}, xptr::Ptr{Cdouble}, n::Cint, gradptr::Ptr{Cdouble})::Cvoid
    st = unsafe_pointer_to_objref(user_data)::CallbackState
    _copy_x!(st.x, xptr, n)
    fill!(st.grad, 0.0)
    MOI.eval_objective_gradient(st.evaluator, st.grad, st.x)
    unsafe_copyto!(gradptr, pointer(st.grad), Int(n))
    return
end

function jl_eval_g(user_data::Ptr{Cvoid}, xptr::Ptr{Cdouble}, n::Cint, gptr::Ptr{Cdouble}, m::Cint)::Cvoid
    st = unsafe_pointer_to_objref(user_data)::CallbackState
    _copy_x!(st.x, xptr, n)
    fill!(st.g, 0.0)
    MOI.eval_constraint(st.evaluator, st.g, st.x)
    unsafe_copyto!(gptr, pointer(st.g), Int(m))
    return
end

function jl_eval_jac_g(user_data::Ptr{Cvoid}, xptr::Ptr{Cdouble}, n::Cint, valuesptr::Ptr{Cdouble}, nnz::Cint)::Cvoid
    st = unsafe_pointer_to_objref(user_data)::CallbackState
    _copy_x!(st.x, xptr, n)
    fill!(st.jac, 0.0)
    MOI.eval_constraint_jacobian(st.evaluator, st.jac, st.x)
    unsafe_copyto!(valuesptr, pointer(st.jac), Int(nnz))
    return
end
