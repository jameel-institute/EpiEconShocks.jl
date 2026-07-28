using Test
using EpiEconShocks

@testset "is_npi_active" begin
    @testset "Basic functionality" begin
        time = [1.0, 2.5, 5.0]
        bounds = [(1.0, 2.0), (4.0, 6.0)]
        result = EpiEconShocks.Tools.is_npi_active(time, bounds)

        @test result == [1.0, 0.0, 1.0]
        @test length(result) == length(time)
        @test all(r in [0.0, 1.0] for r in result)
    end

    @testset "Single timepoint" begin
        time = [3.0]
        bounds = [(1.0, 2.0), (2.5, 4.0)]
        result = EpiEconShocks.Tools.is_npi_active(time, bounds)

        @test result == [1.0]
    end

    @testset "Single bound" begin
        time = [0.5, 1.5, 2.5]
        bounds = [(1.0, 2.0)]
        result = EpiEconShocks.Tools.is_npi_active(time, bounds)

        @test result == [0.0, 1.0, 0.0]
    end

    @testset "Multiple bounds, overlapping intervals" begin
        time = [1.5]
        bounds = [(1.0, 2.0), (1.25, 1.75)]
        result = EpiEconShocks.Tools.is_npi_active(time, bounds)

        @test result == [1.0]
    end

    @testset "Timepoint at bound boundaries" begin
        time = [1.0, 2.0, 1.5]
        bounds = [(1.0, 2.0)]
        result = EpiEconShocks.Tools.is_npi_active(time, bounds)

        @test result == [1.0, 1.0, 1.0]
    end

    @testset "All timepoints outside bounds" begin
        time = [0.1, 0.2, 10.0, 11.0]
        bounds = [(1.0, 2.0), (3.0, 4.0)]
        result = EpiEconShocks.Tools.is_npi_active(time, bounds)

        @test result == [0.0, 0.0, 0.0, 0.0]
    end

    @testset "All timepoints inside bounds" begin
        time = [1.5, 2.5, 3.5, 4.5]
        bounds = [(1.0, 5.0)]
        result = EpiEconShocks.Tools.is_npi_active(time, bounds)

        @test all(result .== 1.0)
    end

    @testset "Input validation: invalid bounds (lower > upper)" begin
        time = [1.0, 2.0, 3.0]
        bounds = [(2.0, 1.0)]

        @test_throws ArgumentError EpiEconShocks.Tools.is_npi_active(time, bounds)
    end

    @testset "Input validation: multiple invalid bounds" begin
        time = [1.0, 2.0]
        bounds = [(1.0, 2.0), (5.0, 4.0)]

        @test_throws ArgumentError EpiEconShocks.Tools.is_npi_active(time, bounds)
    end

    @testset "Input validation: empty bounds" begin
        time = [1.0, 2.0, 3.0]
        bounds = Tuple{Float64, Float64}[]

        @test_throws ArgumentError EpiEconShocks.Tools.is_npi_active(time, bounds)
    end

    @testset "Magnitude warning: bounds much larger than time" begin
        time = [1.0, 2.0]
        bounds = [(1e3, 2e3)]

        @test_warn r"Bounds and time vector differ" EpiEconShocks.Tools.is_npi_active(time, bounds)
    end

    @testset "Magnitude warning: bounds much smaller than time" begin
        time = [1e3, 2e3]
        bounds = [(1.0, 2.0)]

        @test_warn r"Bounds and time vector differ" EpiEconShocks.Tools.is_npi_active(time, bounds)
    end

    @testset "No warning: magnitude difference < 3 orders" begin
        time = [1.0, 2.0, 3.0]
        bounds = [(10.0, 20.0)]

        @test_nowarn EpiEconShocks.Tools.is_npi_active(time, bounds)
    end

    @testset "Return type is Vector{Float64}" begin
        time = [1.0, 2.0, 3.0]
        bounds = [(1.0, 2.0)]
        result = EpiEconShocks.Tools.is_npi_active(time, bounds)

        @test isa(result, Vector{Float64})
    end
end
