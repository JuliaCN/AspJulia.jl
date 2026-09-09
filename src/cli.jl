mutable struct AspJuliaCliOptions
    workspace_root::String
    verification_tasks::Bool
    verification_tasks_json::Bool
    verification_profile::Bool
    verification_profile_json::Bool
    verification_receipt_template::Bool
    verification_receipts_path::Union{Nothing,String}
    verification_receipts_json::Bool
    help::Bool
end

function default_asp_julia_cli_options()
    AspJuliaCliOptions(
        pwd(),
        false,
        false,
        false,
        false,
        false,
        nothing,
        false,
        false,
    )
end

"""Run the ASP Julia command-line interface."""
run_asp_julia_cli(args=ARGS; out=stdout, err=stderr) =
    run_asp_julia_cli(args, out, err)

function run_asp_julia_cli(args, out::IO, err::IO)
    try
        run_asp_julia_cli_checked(String.(collect(args)); out, err)
    catch caught
        println(err, "error: $(julia_cli_error_message(caught))")
        2
    end
end

function julia_cli_error_message(caught)::String
    caught isa ErrorException && return compact_error_message(caught.msg)
    caught isa ArgumentError && return compact_error_message(caught.msg)
    caught isa TOML.ParserError && return project_parse_error_message(caught)
    return "provider command failed"
end

run_asp_julia_cli_checked(args::Vector{String}; out=stdout, err=stderr) =
    run_asp_julia_cli_checked(args, out, err)

function run_asp_julia_cli_checked(args::Vector{String}, out::IO, err::IO)
    if args == ["serve"]
        return run_asp_client_server()
    end
    if !isempty(args) && first(args) == "query"
        return run_asp_julia_query_cli(args[2:end]; out=out)
    end
    protocol_status = run_asp_julia_protocol_cli(args; out)
    !isnothing(protocol_status) && return protocol_status
    isempty(args) && begin
        print(out, asp_julia_cli_usage())
        return 0
    end

    options = parse_asp_julia_cli_args(args)
    if options.help
        print(out, asp_julia_cli_usage())
        return 0
    end
    validate_asp_julia_cli_options(options)
    if options.verification_tasks
        index = build_asp_julia_verification_task_index(options.workspace_root)
        print(out, render_asp_julia_verification_task_index(index))
        return 0
    elseif options.verification_tasks_json
        index = build_asp_julia_verification_task_index(options.workspace_root)
        print(out, render_asp_julia_verification_task_index_json(index))
        print(out, "\n")
        return 0
    elseif options.verification_profile
        profile = build_asp_julia_verification_profile(options.workspace_root)
        print(out, render_asp_julia_verification_profile(profile))
        return 0
    elseif options.verification_profile_json
        profile = build_asp_julia_verification_profile(options.workspace_root)
        print(out, render_asp_julia_verification_profile_json(profile))
        print(out, "\n")
        return 0
    elseif options.verification_receipt_template
        index = build_asp_julia_verification_task_index(options.workspace_root)
        print(out, render_asp_julia_verification_receipt_template(index))
        print(out, "\n")
        return 0
    elseif !isnothing(options.verification_receipts_path)
        index = build_asp_julia_verification_task_index(options.workspace_root)
        receipts = read_julia_verification_receipts_json(options.verification_receipts_path)
        reviews = review_asp_julia_verification_receipts(index, receipts)
        if options.verification_receipts_json
            print(out, render_asp_julia_verification_receipt_reviews_json(reviews))
            print(out, "\n")
        else
            print(
                out,
                render_asp_julia_verification_receipt_reviews(
                    reviews;
                    project_root=index.project_root,
                ),
            )
        end
        return all(is_julia_verification_receipt_review_clean, reviews) ? 0 : 1
    end
    error("policy evaluation is available only through the ASP Julia API")
end

function run_asp_julia_protocol_cli(args::Vector{String}; out=stdout)
    isempty(args) && return nothing
    command = first(args)
    if command == "guide"
        workspace_root = length(args) >= 2 ? args[2] : pwd()
        print(out, render_asp_julia_agent_guide(workspace_root))
        return 0
    elseif command == "agent"
        length(args) >= 2 || error("agent requires a subcommand")
        subcommand = args[2]
        if subcommand == "registry" || subcommand == "doctor"
            json = false
            workspace_root = pwd()
            for arg in args[3:end]
                if arg == "--json"
                    json = true
                elseif startswith(arg, "--")
                    error("unknown agent $(subcommand) option: $(arg)")
                else
                    workspace_root = arg
                end
            end
            if json
                print(out, render_asp_julia_agent_registry_json(workspace_root))
                print(out, "\n")
            else
                print(out, render_asp_julia_agent_registry(workspace_root))
            end
        else
            error("unknown agent subcommand: $(subcommand)")
        end
        return 0
    elseif command == "batch"
        return run_asp_julia_batch_cli(args[2:end]; out)
    elseif command == "export"
        return run_asp_julia_export_cli(args[2:end]; out)
    end
    nothing
end

"""Render the agent-facing Julia provider guide.

The root ASP Client owns search composition. The Julia provider sends discovery
through that public playbook and publishes native syntax facts without a
provider-local graph derivation path.
"""
function render_asp_julia_agent_guide(workspace_root::AbstractString)
    root = abspath(String(workspace_root))
    workspace = "--workspace <workspace-root>"
    """
    [asp-julia-guide] workspace=$(root)
    |catalog provider=native-facts routes=search-playbook
    |route search-playbook returns=candidates,native-syntax,lexical-rank,graph-expansion cmd=asp julia search playbook <query> $(workspace)
    |cmd playbook=asp julia search playbook <query> $(workspace)
    |policy authority=AspJulia-api trigger=Pkg.test
    |rule agent hook install/runtime is owned by asp
    |rule exact query requires a parser-owned selector; Julia does not yet declare typed native exact projection
    |rule the root ASP Client owns the only public search surface; provider-local search views are removed
    |rule native JuliaSyntax facts remain provider-owned inputs to the root search playbook
    |rule use the asp julia facade; run one command at a time; no raw Julia source reads
    |subagent give one |cmd line; require evidence/missing/next/risk
    """
end

function run_asp_julia_batch_cli(args::Vector{String}; out=stdout)
    isempty(args) || error("batch does not accept positional arguments")
    status = 0
    for (index, line) in enumerate(split(read(stdin, String), '\n'))
        isempty(strip(line)) && continue
        step_args = String.(split(line, '\t'; keepempty=false))
        buffer = IOBuffer()
        started = time_ns()
        step_status = run_asp_julia_protocol_cli(step_args; out=buffer)
        elapsed_ms = round(Int, (time_ns() - started) / 1_000_000)
        isnothing(step_status) && error("batch step $(index) must be a protocol command")
        step_output = String(take!(buffer))
        println(out, "%%ASP_JULIA_BATCH_STEP\t$(index)\t$(step_status)\t$(sizeof(step_output))\t$(elapsed_ms)")
        print(out, step_output)
        endswith(step_output, "\n") || println(out)
        println(out, "%%ASP_JULIA_BATCH_END\t$(index)")
        status = max(status, step_status)
    end
    status
end

function parse_asp_julia_cli_args(args::Vector{String})
    options = default_asp_julia_cli_options()
    positionals = String[]
    index = 1
    while index <= length(args)
        arg = args[index]
        if arg in ("-h", "--help")
            options.help = true
        elseif arg == "--verification-tasks"
            options.verification_tasks = true
        elseif arg == "--verification-tasks-json"
            options.verification_tasks_json = true
        elseif arg == "--verification-profile"
            options.verification_profile = true
        elseif arg == "--verification-profile-json"
            options.verification_profile_json = true
        elseif arg == "--verification-receipt-template"
            options.verification_receipt_template = true
        elseif arg == "--verification-receipts"
            index += 1
            index <= length(args) || error("--verification-receipts requires a JSON file")
            options.verification_receipts_path = args[index]
        elseif arg == "--verification-receipts-json"
            index += 1
            index <= length(args) || error("--verification-receipts-json requires a JSON file")
            options.verification_receipts_path = args[index]
            options.verification_receipts_json = true
        elseif startswith(arg, "--")
            error("unknown option: $(arg)")
        else
            push!(positionals, arg)
        end
        index += 1
    end
    length(positionals) <= 1 || error("expected at most one WORKSPACE_ROOT")
    !isempty(positionals) && (options.workspace_root = only(positionals))
    options
end

function validate_asp_julia_cli_options(options::AspJuliaCliOptions)
    modes = count(identity, [
        options.verification_tasks,
        options.verification_tasks_json,
        options.verification_profile,
        options.verification_profile_json,
        options.verification_receipt_template,
        !isnothing(options.verification_receipts_path),
    ])
    modes <= 1 || error("expected only one output mode")
    options
end

function asp_julia_cli_usage()
    """
    asp-julia [guide | agent doctor --json | --verification-tasks | --verification-tasks-json | --verification-profile | --verification-profile-json | --verification-receipt-template | --verification-receipts FILE | --verification-receipts-json FILE] [options] [WORKSPACE_ROOT]

    Use guide to print provider-owned agent commands.
    Use --verification-tasks to emit agent-runnable verification duties.
    Use --verification-receipt-template to emit a JSON receipt skeleton.
    Use --verification-receipts FILE to review agent-submitted verification receipts.
    Use --verification-profile to emit the in-test verification profile.
    """
end
