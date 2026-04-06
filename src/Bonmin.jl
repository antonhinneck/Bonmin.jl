module Bonmin

    __precompile__(true)
    import MathOptInterface as MOI

    const libbonmin = joinpath(@__DIR__, "..", "deps", "lib", "libbonmin_bridge.so")

    include("moi_wrapper.jl")
    include("callbacks.jl")
    include("translate.jl")
    include("results.jl")

    export Optimizer

end