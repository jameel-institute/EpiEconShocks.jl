# basic check that this function works
@testset "Example epidemic data can be loaded" begin
    data = get_example_epi_data()
    @test isa(data, DataFrame)
    @test !isempty(data)
    @test issubset(
        ["time", "compartment", "value", "age_group",
            "vaccine_group", "econ_sector"],
        names(data))
end
