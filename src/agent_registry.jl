include("agent_registry/core.jl")

function julia_agent_method_descriptors()
    [
        julia_query_method_descriptor(),
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

"""Return Julia-owned schema registrations.

Julia currently owns no semantic schema. Shared protocol schemas are projected
by Runtime Server and must never be reconstructed by scanning this package.
"""
asp_julia_schema_registrations() = Dict{String,String}[]

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
