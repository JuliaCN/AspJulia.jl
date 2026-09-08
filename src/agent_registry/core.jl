const JULIA_AGENT_REGISTRY_ID = "agent.semantic-protocols.semantic-language-registry"
const JULIA_AGENT_REGISTRY_VERSION = "1"
const JULIA_AGENT_REGISTRY_PROTOCOL_ID = "agent.semantic-protocols.semantic-language"
const JULIA_AGENT_REGISTRY_PROTOCOL_VERSION = "1"
const JULIA_AGENT_PROVIDER_NAMESPACE =
    "agent.semantic-protocols.languages.julia.asp-julia"
const JULIA_AGENT_BINARY = "asp-julia"

function julia_query_method_descriptor()
    Dict{String,Any}(
        "method" => "query/direct-source-read",
        "command" => "query",
        "input" => "hook-selector",
        "requiredOptions" => ["--from-hook", "--selector"],
        "outputModes" => ["frontier", "code", "read-packet"],
        "outputSchemaIds" => [
            "agent.semantic-protocols.semantic-query-packet",
            "agent.semantic-protocols.semantic-read-packet",
        ],
        "supportsCompact" => true,
        "supportsJson" => true,
    )
end

function julia_evidence_method_descriptors()
    [
        Dict{String,Any}(
            "method" => "evidence/graph",
            "command" => "evidence",
            "input" => "provider project root",
            "outputSchemaIds" => ["agent.semantic-protocols.semantic-evidence-graph"],
            "supportsCompact" => true,
            "supportsJson" => true,
        ),
        Dict{String,Any}(
            "method" => "evidence/analyze",
            "command" => "evidence",
            "input" => "provider project root",
            "outputSchemaIds" => [
                "agent.semantic-protocols.semantic-graph-turbo-request",
            ],
            "packetSchemas" => ["semantic-graph-turbo-request.v1"],
                "clients" => ["asp-python-graphs"],
            "supportsCompact" => true,
            "supportsJson" => true,
        ),
    ]
end
