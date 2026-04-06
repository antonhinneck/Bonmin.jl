#  Bonmin.jl
[![CI](https://github.com/antonhinneck/Bonmin.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/antonhinneck/Bonmin.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/antonhinneck/Bonmin.jl/graph/badge.svg?token=QJ4HQ4QZCM)](https://codecov.io/gh/antonhinneck/Bonmin.jl)

[Bonmin.jl](https://github.com/antonhinneck/Bonmin.jl) is a wrapper for the [Bonmin (Basic Open-source Nonlinear Mixed INteger programming)](https://github.com/coin-or/bonmin) solver.

The wrapper has two components:

 * a thin wrapper around the complete C++ API
 * an interface to [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl)

## Affiliation

This project is currently privately maintained.

## License

tba

## Installation

### System setup to use Bonmin
Currently only ubuntu is tried and tested.
```bash
sudo apt-get update
sudo apt-get install -y \
coinor-libbonmin-dev \
coinor-libipopt-dev \
coinor-libcbc-dev \
coinor-libclp-dev \
g++
```

### System setup to use Bonmin
Install Bonmin.jl using `Pkg.add`:
```julia
import Pkg
Pkg.add(url="https://github.com/antonhinneck/Bonmin.jl")
Pkg.build("Bonmin")
```

## Use with JuMP

To use Bonmin with JuMP, use `Bonmin.Optimizer`:
```julia
using JuMP, Bonmin
model = Model(Bonmin.Optimizer)
@variable(model, x >= 0, Bin)
@variable(model, y >= 0, Int)
@variable(model, z >= 0)
@NLobjective(model, Min, cos(x) + cos(y) + cos(z))
optimize!(model)

println(value(x)) # 1
println(value(y)) # 3
println(value(z)) # pi
println(objective_value(model)) # -1.4496901...
```