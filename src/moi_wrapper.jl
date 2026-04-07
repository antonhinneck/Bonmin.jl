import MathOptInterface as MOI

mutable struct Optimizer <: MOI.AbstractOptimizer
    model::MOI.Utilities.UniversalFallback{MOI.Utilities.Model{Float64}}
    n::Int
    m::Int
    termination_status::MOI.TerminationStatusCode
    primal_status::MOI.ResultStatusCode
    objective_value::Float64
    solution::Vector{Float64}
    debug::Bool

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
            false
        )
    end
end

# -------------------------
# Support declarations
# -------------------------

MOI.supports_incremental_interface(::Optimizer) = false

# variable constraints
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Interval{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.EqualTo{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Integer}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.ZeroOne}) = true

# scalar affine constraints
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarAffineFunction{Float64}}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarAffineFunction{Float64}}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarAffineFunction{Float64}}, ::Type{MOI.EqualTo{Float64}}) = true

# scalar nonlinear constraints
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarNonlinearFunction{Float64}}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarNonlinearFunction{Float64}}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarNonlinearFunction{Float64}}, ::Type{MOI.EqualTo{Float64}}) = true

# objectives
MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::MOI.NLPBlock) = true
MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{MOI.VariableIndex}) = true

# -------------------------
# Basic model plumbing
# -------------------------

MOI.is_empty(opt::Optimizer) = MOI.is_empty(opt.model)

function MOI.empty!(opt::Optimizer)
    MOI.empty!(opt.model)
    opt.n = 0
    opt.m = 0
    opt.termination_status = MOI.OPTIMIZE_NOT_CALLED
    opt.primal_status = MOI.NO_SOLUTION
    opt.objective_value = NaN
    empty!(opt.solution)
    return
end

function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike)
    MOI.empty!(dest)
    return MOI.copy_to(dest.model, src)
end

# delegate standard model operations to the internal model
MOI.add_variable(opt::Optimizer) = MOI.add_variable(opt.model)

function MOI.add_constraint(
    opt::Optimizer,
    f::F,
    s::S,
) where {
    F <: Union{MOI.VariableIndex, MOI.ScalarAffineFunction{Float64}},
    S <: Union{
        MOI.GreaterThan{Float64},
        MOI.LessThan{Float64},
        MOI.Interval{Float64},
        MOI.EqualTo{Float64},
        MOI.Integer,
        MOI.ZeroOne,
    },
}
    return MOI.add_constraint(opt.model, f, s)
end

MOI.set(opt::Optimizer, attr::MOI.ObjectiveSense, value) = MOI.set(opt.model, attr, value)
MOI.set(opt::Optimizer, attr::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}, value) = MOI.set(opt.model, attr, value)
MOI.set(opt::Optimizer, attr::MOI.ObjectiveFunction{MOI.VariableIndex}, value) = MOI.set(opt.model, attr, value)
MOI.set(opt::Optimizer, attr::MOI.NLPBlock, value) = MOI.set(opt.model, attr, value)
MOI.set(opt::Optimizer, attr::MOI.VariablePrimalStart, vi::MOI.VariableIndex, value) = MOI.set(opt.model, attr, vi, value)

MOI.get(opt::Optimizer, attr::MOI.ObjectiveSense) = MOI.get(opt.model, attr)
MOI.get(opt::Optimizer, attr::MOI.NLPBlock) = MOI.get(opt.model, attr)
MOI.get(opt::Optimizer, attr::MOI.ListOfVariableIndices) = MOI.get(opt.model, attr)

function MOI.get(opt::Optimizer, attr::MOI.ListOfConstraintIndices{F,S}) where {F,S}
    return MOI.get(opt.model, attr)
end

function MOI.get(opt::Optimizer, attr::MOI.ConstraintFunction, ci::MOI.ConstraintIndex)
    return MOI.get(opt.model, attr, ci)
end

function MOI.get(opt::Optimizer, attr::MOI.ConstraintSet, ci::MOI.ConstraintIndex)
    return MOI.get(opt.model, attr, ci)
end

function MOI.get(opt::Optimizer, attr::MOI.VariablePrimalStart, vi::MOI.VariableIndex)
    return MOI.get(opt.model, attr, vi)
end

# -------------------------
# Result getters
# -------------------------

MOI.get(opt::Optimizer, ::MOI.TerminationStatus) = opt.termination_status
MOI.get(opt::Optimizer, ::MOI.PrimalStatus) = opt.primal_status
MOI.get(opt::Optimizer, ::MOI.ObjectiveValue) = opt.objective_value

function MOI.get(opt::Optimizer, ::MOI.VariablePrimal, vi::MOI.VariableIndex)
    if opt.primal_status == MOI.NO_SOLUTION || isempty(opt.solution)
        error("No primal solution is available.")
    end
    return opt.solution[vi.value]
end