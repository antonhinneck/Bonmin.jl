cd(@__DIR__)
using Pkg
Pkg.activate(pwd())
using Bonmin
using Libdl

## Check lib

lib = Libdl.dlopen("./deps/lib/libbonmin_bridge.so")
Libdl.dlsym(lib, :bonmin_solve_problem)

## Define callbacks

function test_eval_f(user_data::Ptr{Cvoid}, xptr::Ptr{Cdouble}, n::Cint)::Cdouble
    x = unsafe_wrap(Vector{Float64}, xptr, Int(n))
    return (x[1] - 1.0)^2
end

function test_eval_grad_f(user_data::Ptr{Cvoid}, xptr::Ptr{Cdouble}, n::Cint, gradptr::Ptr{Cdouble})::Cvoid
    x = unsafe_wrap(Vector{Float64}, xptr, Int(n))
    g = unsafe_wrap(Vector{Float64}, gradptr, Int(n))
    fill!(g, 0.0)
    g[1] = 2.0 * (x[1] - 1.0)
    return
end

function test_eval_g(user_data::Ptr{Cvoid}, xptr::Ptr{Cdouble}, n::Cint, gptr::Ptr{Cdouble}, m::Cint)::Cvoid
    return
end

function test_eval_jac_g(user_data::Ptr{Cvoid}, xptr::Ptr{Cdouble}, n::Cint, valuesptr::Ptr{Cdouble}, nnz::Cint)::Cvoid
    return
end

const c_test_eval_f = @cfunction(test_eval_f, Cdouble, (Ptr{Cvoid}, Ptr{Cdouble}, Cint))
const c_test_eval_grad_f = @cfunction(test_eval_grad_f, Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Ptr{Cdouble}))
const c_test_eval_g = @cfunction(test_eval_g, Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Ptr{Cdouble}, Cint))
const c_test_eval_jac_g = @cfunction(test_eval_jac_g, Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Ptr{Cdouble}, Cint))

## Minimal model

n = Cint(1)
m = Cint(0)

x_l = [0.0]
x_u = [10.0]
x0  = [2.0]
var_types = Cint[1]

g_l = Float64[]
g_u = Float64[]

jac_i = Cint[]
jac_j = Cint[]
nnz_jac = Cint(0)

x_out = zeros(1)

obj = ccall(
    (:bonmin_solve_problem, "./deps/lib/libbonmin_bridge.so"),
    Cdouble,
    (
        Cint, Cint,
        Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble},
        Ptr{Cint},
        Ptr{Cdouble}, Ptr{Cdouble},
        Ptr{Cint}, Ptr{Cint}, Cint,
        Ptr{Cvoid},
        Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid},
        Ptr{Cdouble},
    ),
    n, m,
    x_l, x_u, x0,
    var_types,
    g_l, g_u,
    jac_i, jac_j, nnz_jac,
    C_NULL,
    c_test_eval_f, c_test_eval_grad_f, c_test_eval_g, c_test_eval_jac_g,
    x_out,
)

println("objective = ", obj)
println("x_out = ", x_out)