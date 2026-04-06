import MathOptInterface as MOI

## Model definition

mutable struct Optimizer <: MOI.AbstractOptimizer
    model::MOI.Utilities.UniversalFallback{MOI.Utilities.Model{Float64}}
    n::Int
    m::Int
    termination_status::MOI.TerminationStatusCode
    primal_status::MOI.ResultStatusCode
    objective_value::Float64
    solution::Vector{Float64}

    function Optimizer()
        model = MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}())
        return new(
            model,
            0,
            0,
            MOI.OPTIMIZE_NOT_CALLED,
            MOI.NO_SOLUTION,
            NaN,
            Float64[],
        )
    end
end

## Support declarations

MOI.supports_incremental_interface(::Optimizer) = false
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Interval{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.EqualTo{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Integer}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.ZeroOne}) = true

MOI.is_empty(opt::Optimizer) = MOI.is_empty(opt.model)
MOI.empty!(opt::Optimizer) = MOI.empty!(opt.model)

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike)
    MOI.empty!(dest.model)
    return MOI.copy_to(dest.model, src)
end

## Getter methods

MOI.get(opt::Optimizer, ::MOI.TerminationStatus) = opt.termination_status
MOI.get(opt::Optimizer, ::MOI.PrimalStatus) = opt.primal_status
MOI.get(opt::Optimizer, ::MOI.ObjectiveValue) = opt.objective_value

function MOI.get(opt::Optimizer, ::MOI.VariablePrimal, vi::MOI.VariableIndex)
    return opt.solution[vi.value]
end