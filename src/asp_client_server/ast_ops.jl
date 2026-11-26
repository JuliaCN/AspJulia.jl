# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Native JuliaSyntax.jl AST inspection (`ast-inspect`) and batched compiler
oracle verification (`ast-verify`) for ASP's `agent-semantic-ast` protocol."""

const JULIA_SYNTAX_SURFACE = Dict{String,Any}(
    "lineComment" => "#",
    "blockComment" => Any["#=", "=#"],
    "delimiterPairs" => Any[Any["(", ")"], Any["[", "]"], Any["{", "}"]],
    "statementTerminator" => nothing,
    "stringDelimiters" => Any["\""],
)

function _julia_ast_extract_name(node::JuliaSyntax.SyntaxNode, kind_str::String)::String
    children = JuliaSyntax.children(node)
    isempty(children) && return ""
    first_child = first(children)
    if kind_str in ("function", "macro")
        return _julia_signature_name(first_child)
    elseif kind_str == "struct"
        # struct [mutable] Name ... or struct Name <: Super
        for child in children
            ck = string(JuliaSyntax.kind(child))
            if ck == "Identifier"
                return string(child.val)
            elseif ck in ("<:", "curly")
                return _julia_signature_name(child)
            end
        end
    elseif kind_str == "abstract"
        return _julia_signature_name(first_child)
    elseif kind_str == "module"
        for child in children
            if string(JuliaSyntax.kind(child)) == "Identifier"
                return string(child.val)
            end
        end
    end
    return ""
end

function _julia_signature_name(node::JuliaSyntax.SyntaxNode)::String
    k = string(JuliaSyntax.kind(node))
    if k == "Identifier"
        return string(node.val)
    end
    children = JuliaSyntax.children(node)
    isempty(children) && return ""
    if k in ("call", "where", "::", "<:", "curly", "macrocall")
        return _julia_signature_name(first(children))
    elseif k == "."
        return _julia_signature_name(last(children))
    end
    for child in children
        name = _julia_signature_name(child)
        !isempty(name) && return name
    end
    return ""
end

function _julia_byte_span(node::JuliaSyntax.SyntaxNode)::Dict{String,Any}
    range = JuliaSyntax.byte_range(node)
    start_byte = max(0, first(range) - 1)
    end_byte = max(start_byte, last(range))
    return Dict{String,Any}("start" => start_byte, "end" => end_byte)
end

function _julia_collect_ast_nodes!(
    path::String,
    parent::Union{Nothing,String},
    node::JuliaSyntax.SyntaxNode,
    out::Vector{Dict{String,Any}},
)
    k = string(JuliaSyntax.kind(node))
    if k in ("toplevel", "block")
        for child in JuliaSyntax.children(node)
            _julia_collect_ast_nodes!(path, parent, child, out)
        end
        return
    end
    mapped = if k == "function"
        ("function", "function", "fn")
    elseif k == "macro"
        ("macro", "macro", "macro")
    elseif k == "struct"
        ("struct", "struct", "struct")
    elseif k == "abstract"
        ("trait", "abstract", "abstract")
    elseif k == "module"
        ("module", "module", "mod")
    elseif k in ("using", "import")
        ("import", k, "import")
    else
        nothing
    end
    if mapped !== nothing
        univ_kind, lang_kind, tag = mapped
        line = Int(JuliaSyntax.source_line(node))
        name = _julia_ast_extract_name(node, k)
        if isempty(name)
            name = "$(tag)_line_$(line)"
        end
        locator = isnothing(parent) ? "$(path)#$(tag):$(name)" : "$(parent)#$(tag):$(name)"
        span = _julia_byte_span(node)
        record = Dict{String,Any}(
            "locator" => locator,
            "kind" => univ_kind,
            "languageKind" => lang_kind,
            "name" => name,
            "line" => line,
            "outerSpan" => span,
            "innerSpan" => span,
            "attrs" => Any[],
        )
        if !isnothing(parent)
            record["parent"] = parent
        end
        push!(out, record)
        if k == "module"
            for child in JuliaSyntax.children(node)
                _julia_collect_ast_nodes!(path, locator, child, out)
            end
        end
    end
    return
end

function _julia_parse_error_diagnostics(err::JuliaSyntax.ParseError)::Vector{Dict{String,Any}}
    diags = Dict{String,Any}[]
    for d in err.diagnostics
        msg = string(d.message)
        expected = String[]
        for tok in ("end", ")", "]", "}")
            if occursin("`$tok`", msg) || occursin("'$tok'", msg) || occursin("expected $tok", lowercase(msg))
                push!(expected, tok)
            end
        end
        b_start = max(0, Int(d.first_byte) - 1)
        b_end = max(b_start, Int(d.last_byte))
        push!(
            diags,
            Dict{String,Any}(
                "byteStart" => b_start,
                "byteEnd" => b_end,
                "message" => msg,
                "expectedTokens" => expected,
            ),
        )
    end
    if isempty(diags)
        push!(
            diags,
            Dict{String,Any}(
                "byteStart" => 0,
                "byteEnd" => 0,
                "message" => "JuliaSyntax parse error",
                "expectedTokens" => String[],
            ),
        )
    end
    return diags
end

function handle_julia_ast_inspect(payload::Dict{String,Any})::Dict{String,Any}
    path = string(get(payload, "path", "<memory>"))
    source = string(get(payload, "sourceUtf8", ""))
    try
        root = JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, source; filename=path)
        nodes = Dict{String,Any}[]
        _julia_collect_ast_nodes!(path, nothing, root, nodes)
        return Dict{String,Any}(
            "accepted" => true,
            "nodes" => nodes,
            "diagnostics" => Any[],
            "syntaxSurface" => JULIA_SYNTAX_SURFACE,
        )
    catch err
        diags = if err isa JuliaSyntax.ParseError
            _julia_parse_error_diagnostics(err)
        else
            [Dict{String,Any}(
                "byteStart" => 0,
                "byteEnd" => 0,
                "message" => sprint(showerror, err),
                "expectedTokens" => String[],
            )]
        end
        return Dict{String,Any}(
            "accepted" => false,
            "nodes" => Any[],
            "diagnostics" => diags,
            "syntaxSurface" => JULIA_SYNTAX_SURFACE,
        )
    end
end

function handle_julia_ast_verify(payload::Dict{String,Any})::Dict{String,Any}
    path = string(get(payload, "path", "<memory>"))
    candidates = get(payload, "candidates", Any[])
    results = Dict{String,Any}[]
    for cand in candidates
        cand_id = string(get(cand, "candidateId", ""))
        source = string(get(cand, "sourceUtf8", ""))
        try
            JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, source; filename=path)
            push!(
                results,
                Dict{String,Any}(
                    "candidateId" => cand_id,
                    "accepted" => true,
                    "diagnostics" => Any[],
                ),
            )
        catch err
            diags = if err isa JuliaSyntax.ParseError
                _julia_parse_error_diagnostics(err)
            else
                [Dict{String,Any}(
                    "byteStart" => 0,
                    "byteEnd" => 0,
                    "message" => sprint(showerror, err),
                    "expectedTokens" => String[],
                )]
            end
            push!(
                results,
                Dict{String,Any}(
                    "candidateId" => cand_id,
                    "accepted" => false,
                    "diagnostics" => diags,
                ),
            )
        end
    end
    return Dict{String,Any}("results" => results)
end
