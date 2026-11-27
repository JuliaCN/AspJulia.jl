using Test
using AspJulia

@testset "JuliaC ASP Julia verification profile" begin
    @test_nowarn assert_asp_julia_test_profile_clean(
        normpath(joinpath(@__DIR__, ".."));
        advice_io=nothing,
    )
end
