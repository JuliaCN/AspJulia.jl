function run_asp_julia_query_cli(
    _args::Vector{String};
    out::IO = stdout,
)
    println(
        out,
        "Julia exact projection requires a parser-owned selector; use `asp search playbook --languages julia --rg -n -e <query> . --tantivy term <query>` for discovery",
    )
    return 2
end
