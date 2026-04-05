## Optimizer

mutable struct BonminOptimizer <: MOI.AbstractOptimizer
    ptr::Ptr{Cvoid}
    num_vars::Int
    sense::MOI.OptimizationSense
end

function BonminOptimizer()
    ptr = bonmin_create()
    return BonminOptimizer(ptr, 0, MOI.MIN_SENSE)
end

function Base.finalize(opt::BonminOptimizer)
    bonmin_free(opt.ptr)
end

## Variables

function MOI.add_variable(opt::BonminOptimizer)
    bonmin_add_variable(opt.ptr, 0.0, 1e20, 0)
    opt.num_vars += 1
    return MOI.VariableIndex(opt.num_vars)
end

MOI.supports(::BonminOptimizer, ::MOI.VariableIndex) = true

function MOI.get(opt::BonminOptimizer, ::MOI.NumberOfVariables)
    return opt.num_vars
end

## Objective

function MOI.set(opt::BonminOptimizer,
                 ::MOI.ObjectiveSense,
                 sense::MOI.OptimizationSense)
    opt.sense = sense
end

function MOI.get(opt::BonminOptimizer,
                 ::MOI.ObjectiveSense)
    return opt.sense
end

## Solution

function MOI.optimize!(opt::BonminOptimizer)
    ccall((:bonmin_solve, lib), Cvoid, (Ptr{Cvoid},), opt.ptr)
end

function MOI.get(opt::BonminOptimizer, ::MOI.TerminationStatus)
    return MOI.SUCCESS
end

function MOI.get(opt::BonminOptimizer,
                 ::MOI.VariablePrimal,
                 v::MOI.VariableIndex)
    return 0.0  # placeholder
end