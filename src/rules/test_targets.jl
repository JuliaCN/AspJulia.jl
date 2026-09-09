function test_target_import_roots(scope::AspJuliaWorkspaceScope)
    Set(get(scope.targets, "test", String[]))
end
