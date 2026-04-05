cd(@__DIR__)
using Pkg
Pkg.activate(pwd())
using Bonmin
using JuMP

model = Model(BonminOptimizer)