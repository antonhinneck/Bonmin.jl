cd(@__DIR__)
using Pkg
Pkg.activate(pwd())
using Bonmin

model = bonmin_create()

bonmin_add_variable(model, 0, 1, true)