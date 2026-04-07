cd(@__DIR__)
using Pkg
Pkg.activate(pwd())
using Bonmin

Pkg.build()