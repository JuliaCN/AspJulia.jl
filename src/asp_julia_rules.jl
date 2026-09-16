const ASP_JULIA_RULES_PATH = joinpath(@__DIR__, "asp-julia-rules.md")

"""Return the source-embedded ASP Julia rule list."""
function asp_julia_rules_markdown()
    read(ASP_JULIA_RULES_PATH, String)
end

"""Render the source-embedded ASP Julia rules as generated Markdown."""
function render_asp_julia_rules_markdown()
    output = [
        "# ASP Julia",
        "",
        "## ASP Julia Rules",
        "",
        "Generated from embedded `src/asp-julia-rules.md`.",
        "",
    ]
    for line in split(asp_julia_rules_markdown(), '\n')
        startswith(line, "- ") || continue
        item = line[3:end]
        parts = split(item, ": "; limit=2)
        length(parts) == 2 || continue
        push!(output, "- **$(parts[1])**: $(parts[2])")
    end
    join(output, "\n") * "\n"
end

"""Write the generated ASP Julia rules into a downstream unit test directory."""
function write_asp_julia_rules_to_unit_tests(unit_test_dir::AbstractString)
    output_path = joinpath(unit_test_dir, "asp-julia-rules.generated.md")
    mkpath(dirname(output_path))
    write(output_path, render_asp_julia_rules_markdown())
    output_path
end
