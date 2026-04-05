module Bonmin

    __precompile__(true)
    import MathOptInterface as MOI

    include("lib.jl")          # 🔵 C bindings
    include("moi_wrapper.jl") # MOI layer

    export bonmin_create, # lib
           bonmin_add_variable,
           BonminOptimizer # moi_wrapper

end