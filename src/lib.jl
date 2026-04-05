const lib = joinpath(@__DIR__, "..", "deps", "lib", "libbonmin_wrapper")

function bonmin_create()
    ccall((:bonmin_create, lib), Ptr{Cvoid}, ())
end

function bonmin_add_variable(model, lb, ub, is_int)
    ccall((:bonmin_add_variable, lib),
          Cvoid,
          (Ptr{Cvoid}, Cdouble, Cdouble, Cint),
          model, lb, ub, is_int)
end