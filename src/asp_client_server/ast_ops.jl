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

function _julia_collect_exports!(node::JuliaSyntax.SyntaxNode, exported::Set{String})
    k = string(JuliaSyntax.kind(node))
    children = JuliaSyntax.children(node)
    children === nothing && return
    if k == "export"
        for child in children
            if string(JuliaSyntax.kind(child)) == "Identifier"
                push!(exported, string(child.val))
            end
        end
        return
    end
    for child in children
        _julia_collect_exports!(child, exported)
    end
end

function _julia_extract_supertype(node::JuliaSyntax.SyntaxNode)::Union{Nothing,String}
    children = JuliaSyntax.children(node)
    children === nothing && return nothing
    for child in children
        ck = string(JuliaSyntax.kind(child))
        if ck == "<:"
            sub = JuliaSyntax.children(child)
            if sub !== nothing && length(sub) >= 2
                sup = _julia_signature_name(sub[2])
                !isempty(sup) && return sup
            end
        end
    end
    return nothing
end

function _julia_collect_ast_nodes!(
    path::String,
    parent::Union{Nothing,String},
    node::JuliaSyntax.SyntaxNode,
    exported::Set{String},
    out::Vector{Dict{String,Any}},
    edges::Vector{Dict{String,Any}},
)
    k = string(JuliaSyntax.kind(node))
    if k in ("toplevel", "block")
        for child in JuliaSyntax.children(node)
            _julia_collect_ast_nodes!(path, parent, child, exported, out, edges)
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
        attrs = Any[]
        if name in exported
            push!(attrs, Dict{String,Any}("key" => "exported", "value" => "true"))
            push!(attrs, Dict{String,Any}("key" => "visibility", "value" => "export"))
        end
        if k == "struct"
            if JuliaSyntax.has_flags(node, JuliaSyntax.MUTABLE_FLAG)
                push!(attrs, Dict{String,Any}("key" => "mutable", "value" => "true"))
            end
        end
        if k in ("struct", "abstract")
            sup = _julia_extract_supertype(node)
            if sup !== nothing
                push!(attrs, Dict{String,Any}("key" => "implements", "value" => sup))
                push!(
                    edges,
                    Dict{String,Any}(
                        "src" => locator,
                        "dst" => sup,
                        "relation" => "implements",
                        "line" => line,
                    ),
                )
            end
        elseif k in ("using", "import")
            for child in JuliaSyntax.children(node)
                imp = _julia_signature_name(child)
                if !isempty(imp)
                    push!(
                        edges,
                        Dict{String,Any}(
                            "src" => path,
                            "dst" => imp,
                            "relation" => "imports",
                            "line" => line,
                        ),
                    )
                end
            end
        end
        record = Dict{String,Any}(
            "locator" => locator,
            "kind" => univ_kind,
            "languageKind" => lang_kind,
            "name" => name,
            "line" => line,
            "outerSpan" => span,
            "innerSpan" => span,
            "attrs" => attrs,
        )
        if !isnothing(parent)
            record["parent"] = parent
        end
        push!(out, record)
        if k == "module"
            for child in JuliaSyntax.children(node)
                _julia_collect_ast_nodes!(path, locator, child, exported, out, edges)
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
        exported = Set{String}()
        _julia_collect_exports!(root, exported)
        nodes = Dict{String,Any}[]
        edges = Dict{String,Any}[]
        _julia_collect_ast_nodes!(path, nothing, root, exported, nodes, edges)
        return Dict{String,Any}(
            "accepted" => true,
            "nodes" => nodes,
            "edges" => edges,
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
            "edges" => Any[],
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
