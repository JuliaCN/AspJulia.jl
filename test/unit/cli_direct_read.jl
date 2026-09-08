using Test

@testset "legacy direct source read projection stays unavailable" begin
    project_root = normpath(joinpath(@__DIR__, "..", ".."))
    out = IOBuffer()
    status = AspJulia.run_asp_julia_query_cli(
        [
            "--from-hook",
            "direct-source-read",
            "--selector",
            "src/cli/query.jl:1:5",
            "--workspace",
            project_root,
            "--code",
        ];
        out,
    )
    rendered = String(take!(out))

    @test status == 2
    @test occursin("requires a parser-owned selector", rendered)
    @test occursin("asp julia search playbook", rendered)
    @test !occursin("semantic-read-packet", rendered)
end
