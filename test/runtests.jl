cd(@__DIR__)
# using Pkg
# Pkg.activate(pwd())

using Test
using Bonmin
using JuMP
import MathOptInterface as MOI

const TOL = 1e-5

@testset "Bonmin basic tests" begin

    @testset "Continuous LP" begin
        model = Model(Bonmin.Optimizer)

        @variable(model, x >= 0)
        @variable(model, 0.4 >= y >= 0)

        @objective(model, Min, 2*x + y)
        @constraint(model, x + y >= 1)

        optimize!(model)

        @test termination_status(model) == MOI.LOCALLY_SOLVED

        @test value(x) ≈ 0.6 atol=TOL
        @test value(y) ≈ 0.4 atol=TOL
        @test objective_value(model) ≈ 1.6 atol=TOL
    end

    @testset "Mixed-integer LP" begin
        model = Model(Bonmin.Optimizer)

        @variable(model, x >= 0, Int)
        @variable(model, 0.4 >= y >= 0)

        @objective(model, Min, 2*x + y)
        @constraint(model, x + y >= 2)

        optimize!(model)

        @test termination_status(model) == MOI.LOCALLY_SOLVED

        @test value(x) ≈ 2.0 atol=TOL
        @test value(y) ≈ 0.0 atol=TOL
        @test objective_value(model) ≈ 4.0 atol=TOL
    end

    @testset "Continuous NLP" begin
        model = Model(Bonmin.Optimizer)

        @variable(model, x >= 0)
        @variable(model, y >= 0)

        @NLobjective(model, Min, (x - 1)^2 + (y - 2)^2)
        @NLconstraint(model, x + y >= 1)

        optimize!(model)

        @test termination_status(model) == MOI.LOCALLY_SOLVED

        @test value(x) ≈ 1 atol=TOL
        @test value(y) ≈ 2 atol=TOL
        @test objective_value(model) ≈ 0 atol=TOL
    end

    @testset "Mixed-integer NLP" begin
        model = Model(Bonmin.Optimizer)

        @variable(model, x >= 0, Bin)
        @variable(model, y >= 0, Int)
        @variable(model, z >= 0)

        @NLobjective(model, Min, cos(x) + cos(y) + cos(z))

        optimize!(model)

        @test termination_status(model) == MOI.LOCALLY_SOLVED

        @test value(x) ≈ 1 atol=TOL
        @test value(y) ≈ 3 atol=TOL
        @test value(z) ≈ π atol=1e-4

        @test objective_value(model) ≈ (cos(1) + cos(3) + cos(π)) atol=1e-5
    end

end