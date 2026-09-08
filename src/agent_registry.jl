include("agent_registry/core.jl")

function julia_agent_method_descriptors()
    [
        julia_query_method_descriptor(),
        julia_evidence_method_descriptors()...,
        Dict{String,Any}(
            "method" => "agent/doctor",
            "command" => "agent",
            "outputSchemaIds" => ["agent.semantic-protocols.semantic-language-registry"],
            "supportsCompact" => true,
            "supportsJson" => true,
        ),
        Dict{String,Any}(
            "method" => "agent/registry",
            "command" => "agent",
            "outputSchemaIds" => ["agent.semantic-protocols.semantic-language-registry"],
            "supportsCompact" => true,
            "supportsJson" => true,
        ),
        Dict{String,Any}(
            "method" => "guide",
            "command" => "guide",
            "clients" => ["codex"],
            "supportsCompact" => true,
            "supportsJson" => false,
        ),
    ]
end

"""Return schema registrations advertised by the Julia provider from `schema_root`.

Throws `ErrorException` when the schema root is missing or a schema document
does not declare a string `schemaId`, `registryId`, or `\$id` identity.
"""
function asp_julia_schema_registrations(
    schema_root::AbstractString=joinpath(normpath(joinpath(@__DIR__, "..")), "schemas"),
)
    isdir(schema_root) || error("schema root does not exist: $(schema_root)")
    registrations = Dict{String,String}[]
    schema_files = filter(
        name -> !startswith(name, ".") && endswith(name, ".json"),
        readdir(schema_root),
    )
    for file_name in sort!(schema_files)
        document = JSON.parsefile(joinpath(schema_root, file_name))
        properties = get(document, "properties", Dict{String,Any}())
        schema_id = get(document, "schemaId", nothing)
        if !(schema_id isa AbstractString)
            schema_id = get(get(properties, "schemaId", Dict{String,Any}()), "const", nothing)
        end
        if !(schema_id isa AbstractString)
            schema_id = get(get(properties, "registryId", Dict{String,Any}()), "const", nothing)
        end
        schema_id isa AbstractString || (schema_id = get(document, "\$id", nothing))
        schema_id isa AbstractString || error("schema $file_name has no string schema identity")
        schema_version = get(document, "schemaVersion", nothing)
        if isnothing(schema_version)
            schema_version = get(
                get(properties, "schemaVersion", Dict{String,Any}()),
                "const",
                nothing,
            )
        end
        if isnothing(schema_version)
            schema_version = get(
                get(properties, "registryVersion", Dict{String,Any}()),
                "const",
                "1",
            )
        end
        push!(registrations, Dict(
            "path" => "schemas/$file_name",
            "schemaId" => String(schema_id),
            "schemaVersion" => string(schema_version),
        ))
    end
    registrations
end

"""Build the Julia semantic-language registry packet for client discovery."""
function asp_julia_agent_registry_packet(workspace_root::AbstractString=pwd())
    descriptors = julia_agent_method_descriptors()
    methods = sort!(unique(String(descriptor["method"]) for descriptor in descriptors))
    root = abspath(String(workspace_root))
    Dict(
        "registryId" => JULIA_AGENT_REGISTRY_ID,
        "registryVersion" => JULIA_AGENT_REGISTRY_VERSION,
        "protocolId" => JULIA_AGENT_REGISTRY_PROTOCOL_ID,
        "protocolVersion" => JULIA_AGENT_REGISTRY_PROTOCOL_VERSION,
        "projectRoot" => root,
        "languages" => [
            Dict(
                "languageId" => JULIA_INDEX_EXPORT_LANGUAGE_ID,
                "providerId" => JULIA_INDEX_EXPORT_PROVIDER_ID,
                "binary" => JULIA_AGENT_BINARY,
                "providerCommandPrefix" => [JULIA_AGENT_BINARY],
                "namespace" => JULIA_AGENT_PROVIDER_NAMESPACE,
                "displayName" => "ASP Julia",
                "methods" => methods,
                "methodDescriptors" => descriptors,
                "schemas" => asp_julia_schema_registrations(),
            ),
        ],
    )
end

"""Render the Julia semantic-language registry packet as JSON."""
function render_asp_julia_agent_registry_json(workspace_root::AbstractString=pwd())
    JSON.json(asp_julia_agent_registry_packet(workspace_root))
end

"""Render a compact Julia provider registry status line."""
function render_asp_julia_agent_registry(workspace_root::AbstractString=pwd())
    packet = asp_julia_agent_registry_packet(workspace_root)
    julia_language = only(filter(language -> language["languageId"] == JULIA_INDEX_EXPORT_LANGUAGE_ID, packet["languages"]))
    "[asp-julia-agent-registry] status=ok provider=$(julia_language["providerId"]) methods=$(length(julia_language["methods"])) schemas=$(length(julia_language["schemas"])) languages=$(length(packet["languages"])) workspace=$(packet["projectRoot"])\n"
end
