cd(@__DIR__)
using Pkg
Pkg.activate(pwd())
using Bonmin
using JuMP
import MathOptInterface as MOI

model = Model(Bonmin.Optimizer)
@variable(model, x >= 0)
@variable(model, y >= 0)
@NLobjective(model, Min, (x - 1)^2 + (y - 2)^2)
@constraint(model, x + y >= 1)
optimize!(model)

println(value(x)) # 1
println(value(y)) # 2
println(objective_value(model)) # 0


## Model 2

cd(@__DIR__)
using Pkg
Pkg.activate(pwd())
using Bonmin
using JuMP
import MathOptInterface as MOI

model = Model(Bonmin.Optimizer)
@variable(model, x >= 0, Bin)
@variable(model, y >= 0, Int)
@variable(model, z >= 0)
@NLobjective(model, Min, cos(x) + cos(y) + cos(z))
@constraint(model, z - y <= 2.0)

function dump_constraint_types(model)
    b = backend(model)
    for (F, S) in MOI.get(b, MOI.ListOfConstraintTypesPresent())
        cis = MOI.get(b, MOI.ListOfConstraintIndices{F,S}())
        println("$(F)-in-$(S): ", length(cis))
    end
end
dump_constraint_types(model)

optimize!(model)

println(value(x)) # 1
println(value(y)) # 3
println(value(z)) # pi
println(objective_value(model)) # -1.4496901...