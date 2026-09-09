"""JuliaSyntax-native policy and semantic tooling for Julia package agent context."""
module AspJulia

using Base64

include("model.jl")
include("parser.jl")
include("rules.jl")
include("rule_visibility.jl")
include("render.jl")
include("runner.jl")
include("runner/package_paths.jl")
include("runner/project_config.jl")
include("runner/project_context.jl")
include("search_index.jl")
include("search_index/tests.jl")
include("search_index/owners.jl")
include("search_index/types.jl")
include("search_index/functions.jl")
include("search_index/moshi.jl")
include("search_index/origin.jl")
include("search_index/verification.jl")
include("asp_export.jl")
include("semantic_graph_project_facts.jl")
include("semantic_graph_facts.jl")
include("asp_julia_rules.jl")
include("agent_registry.jl")
include("asp_query.jl")
include("agent_snapshot.jl")
include("verification.jl")
include("verification/benchmarks.jl")
include("verification/examples.jl")
include("verification/extensions.jl")
include("verification/responsibility_inference.jl")
include("verification/contracts.jl")
include("verification/receipt_templates.jl")
include("verification/receipts.jl")
include("verification/advice.jl")
include("verification/context.jl")
include("verification/profile_index.jl")
include("moshi_extension.jl")
include("queries/flow_lite.jl")
include("cli/query.jl")
include("cli/query_contract.jl")
include("cli/project_resolution.jl")
include("cli/project_resolution_codec.jl")
include("asp_client_server/projection_batch.jl")
include("asp_client_server/contract.jl")
include("asp_client_server/http.jl")
include("cli/query_code.jl")
include("cli.jl")

"""Configure JuliaSyntax only for the closed JuliaC build process.

Safety contract: this fixed parser override runs only while `ASP_JULIA_AOT_BUILD=1`,
before the compiler snapshots the Harness dependency graph; it never mutates a normal
Harness process. The JuliaC compile smoke and compiled `guide`/`export index` tests
verify that the override preserves the parser block contract.
"""
function configure_juliac_aot_syntax!()
    Core.eval(
        JuliaSyntax,
        quote
            function parse_block(ps::ParseState)
                mark = position(ps)
                parse_block_inner(ps, parse_eq)
                emit(ps, mark, K"block")
            end
        end,
    )
    nothing
end

export JuliaDiagnosticSeverity,
    AspJuliaConfig,
    AspJuliaFinding,
    AspJuliaReport,
    AspJuliaRule,
    JuliaRuleVisibility,
    JuliaFileReport,
    JuliaSearchIndexEntry,
    JuliaSearchResult,
    JuliaVerificationProfileCandidate,
    JuliaVerificationProfileIndex,
    JuliaVerificationReceiptReview,
    JuliaVerificationTaskIndex,
    JuliaVerificationTaskRecord,
    JuliaVerificationProfile,
    RulePackDescriptor,
    SourceLocation,
    assert_asp_julia_paths_clean,
    assert_asp_julia_workspace_clean,
    assert_asp_julia_pkg_test_clean,
    assert_asp_julia_test_profile_clean,
    assert_asp_julia_verification_receipts_accepted,
    build_asp_julia_verification_profile,
    build_asp_julia_verification_profile_index,
    build_asp_julia_verification_task_index,
    default_asp_julia_config,
    asp_julia_agent_policy_rules,
    asp_julia_modularity_rules,
    asp_julia_package_policy_rules,
    asp_julia_workspace_search_index,
    asp_julia_rules_markdown,
    asp_julia_agent_registry_packet,
    asp_julia_index_export_packet,
    asp_julia_query_owner_items_packet,
    asp_julia_schema_registrations,
    asp_julia_rule_pack_descriptors,
    asp_julia_rule_visibility,
    asp_julia_syntax_rules,
    asp_julia_paths_search_index,
    moshi_extension_capabilities,
    read_julia_verification_receipts_json,
    render_asp_julia_report,
    render_asp_julia_advice,
    render_asp_julia_agent_snapshot,
    render_asp_julia_report_json,
    render_asp_julia_rules_markdown,
    render_asp_julia_index_export_json,
    render_asp_julia_semantic_graph_facts_json,
    render_asp_julia_agent_registry,
    render_asp_julia_agent_registry_json,
    render_asp_julia_query_owner_items,
    render_asp_julia_query_owner_items_json,
    render_asp_julia_native_owner_items_query_json,
    run_asp_julia_native_owner_items_query_cli,
    render_asp_julia_rule_visibility,
    render_asp_julia_verification_pending_advice,
    render_asp_julia_verification_profile,
    render_asp_julia_verification_profile_index,
    render_asp_julia_verification_profile_index_json,
    render_asp_julia_verification_profile_json,
    render_asp_julia_verification_receipt_template,
    render_asp_julia_verification_receipt_reviews,
    render_asp_julia_verification_receipt_reviews_json,
    render_asp_julia_verification_task_index,
    render_asp_julia_verification_task_index_json,
    review_asp_julia_verification_receipts,
    run_asp_julia_export_cli,
    run_asp_julia_cli,
    run_asp_julia_paths,
    run_asp_julia_workspace,
    search_asp_julia_index,
    search_asp_julia_paths,
    search_asp_julia_workspace,
    write_asp_julia_rules_to_unit_tests

end
