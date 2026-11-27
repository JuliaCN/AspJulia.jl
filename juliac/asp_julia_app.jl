module AspJuliaApp

using AspJulia

if get(ENV, "ASP_JULIA_AOT_BUILD", "0") == "1"
    AspJulia.configure_juliac_aot_syntax!()
end

const NativeOutputIO = IOStream
const NativeInputIO = IOStream

function native_standard_iostream(name::String, fd::Cint)::IOStream
    duplicate_fd = ccall(:dup, Cint, (Cint,), fd)
    duplicate_fd >= 0 || error("failed to duplicate native stdin descriptor")
    return Base.fdio(name, duplicate_fd, true)
end

function run_serve_route(args, out, err)
    args == ["serve"] ||
        return invalid_provider_route("serve does not accept arguments", err)
    return Cint(AspJulia.run_asp_client_server())
end

run_export_route(
    args::Vector{String},
    out::NativeOutputIO,
    err::NativeOutputIO,
)::Cint =
    Cint(AspJulia.run_asp_julia_export_cli(args[2:end]; out))

function run_guide_route(args::Vector{String}, out::NativeOutputIO, err::NativeOutputIO)::Cint
    try
        workspace_root = length(args) >= 3 ? args[3] : pwd()
        print(out, AspJulia.render_asp_julia_agent_guide(workspace_root))
        return Cint(0)
    catch
        println(err, "error: guide route failed")
        return Cint(2)
    end
end

function invalid_provider_route(message::String, err::NativeOutputIO)::Cint
    println(err, "error: ", message)
    return Cint(2)
end

function run_cli_without_stdin(
    args::Vector{String},
    out::NativeOutputIO,
    err::NativeOutputIO,
)::Cint
    try
        isempty(args) && return invalid_provider_route("missing provider route", err)
        command = first(args)
        if command == "export"
            return run_export_route(args, out, err)
        elseif command == "guide" || (command == "agent" && length(args) >= 2 && args[2] == "guide")
            return run_guide_route(args, out, err)
        end
        return invalid_provider_route("unsupported provider route: $(command)", err)
    catch
        println(err, "error: provider route failed")
        return Cint(2)
    end
end

function run_native_cli_concrete(
    args::Vector{String},
    out::O,
    err::E,
    input::I,
)::Cint where {O<:NativeOutputIO,E<:NativeOutputIO,I<:NativeInputIO}
    _ = input
    return run_cli_without_stdin(args, out, err)
end

function run_native_cli(args::Vector{String})::Cint
    input = native_standard_iostream("asp-julia-native-stdin", Cint(0))
    out = native_standard_iostream("asp-julia-native-stdout", Cint(1))
    err = native_standard_iostream("asp-julia-native-stderr", Cint(2))
    try
        return run_native_cli_concrete(args, out, err, input)
    finally
        flush(out)
        flush(err)
        close(input)
        close(out)
        close(err)
    end
end

Base.Experimental.entrypoint(run_native_cli, (Vector{String},))

function run_app(args::Vector{String})::Cint
    return run_native_cli(args)
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(AspJuliaApp.run_app(ARGS))
end

function (@main)(args::Vector{String})::Cint
    return AspJuliaApp.run_app(args)
end
