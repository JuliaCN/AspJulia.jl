# ASP Julia

ASP Julia is the JuliaSyntax-native policy and semantic provider for coding
agents. Its purpose is to help an agent write higher-quality Julia package code:
parser-stable, package-aware, easier for the next agent to understand, and
verified through the same `Pkg.test` loop the package already owns.

This is not a port of another provider. It expresses the shared ASP contracts
through Julia's own package model:

- `Project.toml` and `Pkg` define package roots, dependency scopes, weakdeps,
  extensions, test targets, local source dependencies, and workspace members.
- `JuliaSyntax.jl` defines syntax facts for policy, search, snapshots, and
  repair advice.
- Literal `include(...)` graphs and package entry modules define practical
  owner boundaries.
- Compact text output is the primary agent surface; JSON remains available for
  tools.
- Self-apply stays active, so new policy must also keep ASP Julia repairable.

## Quality For Agents

The core design target is quality for agents, not a generic style checklist.
ASP Julia makes important Julia package facts visible before an agent edits:

- public API intent through docstrings, exports, `public`, and method families;
- public return contracts when exported methods use concrete return
  annotations, plus `@inferred` coverage for those contracts;
- public data-shape quality through typed fields and broad abstract field
  annotations;
- public failure contracts when exported methods throw errors or use
  assertions, plus `@test_throws` coverage for those contracts;
- public mutation contracts for `!` APIs, plus package tests that call those
  mutating methods;
- mutable global state through parser-visible non-const package bindings and
  their initializer shape;
- project ownership through Pkg entry files, local source dependencies,
  declared extensions, test owners, includes, and modules;
- algorithm shape through control-flow depth, branch count, loops, pipeline
  calls, and macro-heavy public surfaces;
- test scenario shape through parser-visible testset control-flow, branch, and
  nested-loop facts;
- safety/performance evidence contracts for unsafe constructs, plus package
  tests that call those public APIs;
- dependency shape through `[deps]`, `[weakdeps]`, `[extensions]`, `[compat]`,
  `[extras]`, `[targets]`, `[sources]`, and `[workspace]`;
- verification duties through package tests, syntax search, docs/doctests,
  package-owned examples, extension boundaries, project-owned benchmark/perf
  gates, performance, stress, and chaos task advice;
- verification duties as provider-owned context for the root ASP search
  playbook, including examples, benchmarks, docs, extensions, and
  receipt-required gates;
- policy escape surfaces that require concrete explanations instead of silent
  suppression.

The intended reader of the output is an agent. A Julia package can compile and
still be difficult for an agent to repair safely if intent, ownership,
verification, or domain modeling is hidden in broad stringly code.

## ASP Julia Surfaces

The root ASP Client owns the public search surface. ASP Julia supplies native
JuliaSyntax facts through the Runtime-owned provider path:

```sh
asp julia guide --workspace .
asp search playbook --languages julia --rg -n -e <query> . --tantivy term <query>
asp julia agent doctor --workspace . --json
```

The package-local executable exposes the same provider routes for development:

```sh
julia --project=. bin/asp-julia.jl guide .
julia --project=. bin/asp-julia.jl agent doctor --json .
```

## Rule Packs

Current rule packs are split by intent:

- `julia.syntax`: blocking JuliaSyntax parse failures.
- `julia.project_policy`: blocking package, dependency, extension, test target,
  and scope-policy checks.
- `julia.modularity`: blocking Project.toml-owned Julia owner and include-graph
  checks across source, extension, and test scopes.
- `julia.agent_policy`: advisory repair guidance for agent-friendly Julia APIs,
  tests, docs, data shape, return/type-stability contracts, failure contracts,
  mutation contracts, test scenario shape, unsafe evidence coverage, type
  coverage, Moshi domain modeling, mutable global state, and type-piracy risk.

Advisory does not mean cosmetic. It means the package remains runnable while
ASP Julia tells the agent what would make the next repair safer.

## Verification Loop

For the ASP Julia repository, use:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

`Manifest.toml` is generated locally by `Pkg.instantiate()` and `Pkg.test()`.
This repository is a provider package, so the root manifest should not be
committed unless the package contract changes deliberately.

## Moshi Extension

Moshi is optional. ASP Julia models it with Julia package extension mechanics:

- root `[weakdeps]` declares `Moshi`;
- `[extensions]` declares `AspJuliaMoshiExt = "Moshi"`;
- `[targets] test` activates Moshi for package tests;
- core ASP Julia code does not require Moshi to load first.

Moshi facts are parser-visible through `@data`, `@match`, and `@derive`.
Stringly branch dispatch is not satisfied by any random Moshi macro: when branch
literals are parser-visible, the Moshi `@data` variants must cover those domain
literals. A covered `@data` model should then be wired into real project logic
with parser-visible `@match` cases or typed methods, so agents use Moshi as a
domain bridge rather than as an unused policy token.

Downstream packages that set `[tool.AspJulia] moshi = "enable"`
are declaring Moshi as a source-level modeling practice, not as a test-only
experiment. ASP Julia therefore requires `Moshi` in `[deps]` and uses native
Julia parser facts to point agents at the nearest stringly branch domain that
should be converted into a parser-visible Moshi model.
The parser follows Moshi's public ADT and match shapes, including singleton
variants, call-style variants, named `struct` variants, and `@match` cases that
combine multiple patterns with `||`.

## Documentation Map

Start here:

- `docs/superpowers/research/2026-05-20-julia-project-quality-for-agents.md`
  explains the quality model calibrated from Julia, Pkg, Documenter, and mature
  package practices.
- `docs/superpowers/specs/2026-05-20-julia-syntax-harness-alignment-design.md`
  records the original parser-first design and its policy roadmap.

When adding new policy, prefer parser facts first, then compact agent output,
then tests that prove the advice cannot be bypassed by configuration alone.
