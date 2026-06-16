# basic check that this function works
@testset "Example epidemic data can be loaded" begin
    data = get_example_epi_data()
    @test isa(data, DataFrame)
end
