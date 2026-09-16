@testset "json render" begin
    temp = mktempdir()
    source = joinpath(temp, "valid.jl")
    write(source, "value() = 1\n")

    report = run_asp_julia_paths([source])
    json = render_asp_julia_report_json(report)

    @test occursin("\"files\"", json)
    @test occursin("\"findings\"", json)
    @test occursin("\"blocking_severities\"", json)
end

@testset "json render exposes config escape finding" begin
    temp = mktempdir()
    source = joinpath(temp, "valid.jl")
    write(source, "value() = 1\n")
    config = default_asp_julia_config()
    push!(config.disabled_rules, "JULIA-SYN-R001")

    report = run_asp_julia_paths([source]; config)
    json = render_asp_julia_report_json(report)

    @test occursin("JULIA-AGENT-PROJECT-014", json)
    @test occursin("ASP Julia config escape lacks explanation", json)
end
