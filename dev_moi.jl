cd(@__DIR__)
using Pkg
Pkg.activate(pwd())
using Bonmin
import MathOptInterface as MOI

opt = Bonmin.Optimizer()
MOI.add_variable(opt)
MOI.add_variable(opt)
MOI.optimize!(opt)
show(opt)
print(opt)