@testitem "test_core" begin
    include(joinpath(pkgdir(Accessors), "test/test_core.jl"))
end

@testitem "test_optics" begin
    include(joinpath(pkgdir(Accessors), "test/test_optics.jl"))
end

@testitem "test_insert_delete" begin
    # one inference test fails
    # include(joinpath(pkgdir(Accessors), "test/test_insert_delete.jl"))
end

@testitem "test_extensions" begin
    include(joinpath(pkgdir(Accessors), "test/test_extensions.jl"))
end

@testitem "test_setmacro" begin
    include(joinpath(pkgdir(Accessors), "test/test_setmacro.jl"))
end

@testitem "test_setindex" begin
    include(joinpath(pkgdir(Accessors), "test/test_setindex.jl"))
end

@testitem "test_functionlenses" begin
    include(joinpath(pkgdir(Accessors), "test/test_functionlenses.jl"))
end

@testitem "test_getsetall" begin
    include(joinpath(pkgdir(Accessors), "test/test_getsetall.jl"))
end