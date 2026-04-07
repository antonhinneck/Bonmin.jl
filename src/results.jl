import MathOptInterface as MOI

function _set_dummy_success!(opt::Optimizer, x::Vector{Float64}, obj::Float64)
    opt.solution = x
    opt.objective_value = obj
    opt.termination_status = MOI.LOCALLY_SOLVED
    opt.primal_status = MOI.FEASIBLE_POINT
end

function MOI.optimize!(opt::Optimizer)
    flat = build_flat_model(opt.model)

    @show flat.m_aff
    @show flat.A_i
    @show flat.A_j
    @show flat.A_v
    @show flat.g_l_aff
    @show flat.g_u_aff

    # state
    st = make_state(flat)
    x_out = copy(flat.x0)

    # merged constraint bounds
    g_l = vcat(flat.g_l_nlp, flat.g_l_aff)
    g_u = vcat(flat.g_u_nlp, flat.g_u_aff)

    # combined Jacobian structure
    jac_i = flat.jac_i
    jac_j = flat.jac_j
    nnz_jac = length(jac_i)

    # shortcuts
    x_l = flat.x_l
    x_u = flat.x_u
    x0 = flat.x0
    var_types = flat.var_types

    # validation
    @assert length(jac_i) == length(jac_j)
    @assert length(g_l) == flat.m
    @assert length(g_u) == flat.m
    @assert flat.m == flat.m_nlp + flat.m_aff

    c_eval_f = @cfunction(jl_eval_f, Cdouble, (Ptr{Cvoid}, Ptr{Cdouble}, Cint))
    c_eval_grad_f = @cfunction(jl_eval_grad_f, Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Ptr{Cdouble}))
    c_eval_g = @cfunction(jl_eval_g, Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Ptr{Cdouble}, Cint))
    c_eval_jac_g = @cfunction(jl_eval_jac_g, Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Ptr{Cdouble}, Cint))

    obj = GC.@preserve flat st x_l x_u x0 var_types g_l g_u jac_i jac_j x_out begin
        ccall(
            (:bonmin_solve_problem, libbonmin),
            Cdouble,
            (
                Cint, Cint, Cint,
                Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble},
                Ptr{Cint},
                Ptr{Cdouble}, Ptr{Cdouble},
                Ptr{Cint}, Ptr{Cint}, Cint,
                Ptr{Cvoid},
                Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid},
                Ptr{Cdouble},
            ),
            flat.n,
            flat.m,
            flat.m_nlp,
            x_l, x_u, x0,
            var_types,
            g_l, g_u,
            jac_i, jac_j, nnz_jac,
            Base.pointer_from_objref(st),
            c_eval_f, c_eval_grad_f, c_eval_g, c_eval_jac_g,
            x_out,
        )
    end

    _set_dummy_success!(opt, x_out, obj)
    return
end