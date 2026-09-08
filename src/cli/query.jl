function run_asp_julia_query_cli(
    _args::Vector{String};
    out::IO = stdout,
)
    println(
        out,
        "Julia exact projection requires a parser-owned selector; use `asp julia search playbook <query> --workspace <workspace-root>` for discovery",
    )
    return 2
end
