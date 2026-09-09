@testset "ASP Julia rules" begin
    raw = asp_julia_rules_markdown()
    lines = split(chomp(raw), '\n')

    rule_ids = String[]

    @test length(lines) == 52
    for line in lines
        @test startswith(line, "- ")
        parts = split(line[3:end], ": "; limit=2)
        @test length(parts) == 2
        rule_id, sentence = parts
        push!(rule_ids, rule_id)
        @test startswith(rule_id, "AGENT-JL-R") ||
              startswith(rule_id, "JULIA-AGENT-PROJECT") ||
              startswith(rule_id, "JULIA-MOD-R") ||
              startswith(rule_id, "JULIA-PROJ-R")
        @test endswith(sentence, ".")
        @test !occursin(r"[!?]", sentence)
        @test !occursin(r"\.\s+\S", sentence[1:end - 1])
    end
    catalog_rule_ids = [
        rule.rule_id for rule in vcat(
            asp_julia_agent_policy_rules(),
            asp_julia_modularity_rules(),
            asp_julia_package_policy_rules(),
        )
    ]
    @test sort(rule_ids) == sort(catalog_rule_ids)

    unit_dir = @__DIR__
    if get(ENV, "UPDATE_ASP_JULIA_RULES", "") != ""
        write_asp_julia_rules_to_unit_tests(unit_dir)
    end
    fixture = joinpath(unit_dir, "asp-julia-rules.generated.md")
    @test read(fixture, String) == render_asp_julia_rules_markdown()

    temp_dir = mktempdir()
    try
        output = write_asp_julia_rules_to_unit_tests(temp_dir)
        @test output == joinpath(temp_dir, "asp-julia-rules.generated.md")
        @test read(output, String) == render_asp_julia_rules_markdown()
    finally
        rm(temp_dir; recursive=true, force=true)
    end
end
