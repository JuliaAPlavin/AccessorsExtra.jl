@testitem "shorter aliases" begin
    @test @o(_.a[∗].b[∗ₚ].c[2]) === @optic(_.a |> Elements() |> _.b |> Properties() |> _.c[2])
end

@testitem "and/or/..." begin
    @test (<(5) ⩓ >(1) ⩓ >(2))(3)
    @test !(<(5) ⩓ >(1) ⩓ >(2))(2)
    @test (<(5) ⩓ >(1) ⩔ >(2))(2)
    @test (<(5) ⩓ >(1) ⩔ >(2))(6)
    @test !(<(5) ⩓ >(1) ⩔ >(2))(0)
    @test !(<(5) ⩓ (x->throw("")))(6)
    @test (<(5) ⩔ (x->throw("")))(4)
end

@testitem "fixargs" begin
    AccessorsExtra.@allinferred o begin
    o = @o tuple(_)
    @test o(0) === (0,)
    o = @o tuple(1, _)
    @test o(0) === (1, 0)
    o = @o tuple(_, 1)
    @test o(0) === (0, 1)

    o = @o tuple(1, 2, _)
    @test o(0) === (1, 2, 0)
    o = @o tuple(1, _, 2)
    @test o(0) === (1, 0, 2)
    o = @o tuple(_, 1, 2)
    @test o(0) === (0, 1, 2)

    o = @o sort(_, by=identity)
    @test o([-3, 1, 2, 0]) == [-3, 0, 1, 2]
    o = @o sort(_, by=abs)
    @test o([-3, 1, 2, 0]) == [0, 1, 2, -3]
    end

    @test_broken @eval (@o sort(_; by=identity))([-3, 1, 2, 0]) == [-3, 0, 1, 2]
    @test_broken @eval (@o sort(_; by=abs))([-3, 1, 2, 0]) == [0, 1, 2, -3]

    @test (@o atan(_...)) === splat(atan)
    @test (@o atan(reverse(_)...)) === splat(atan) ∘ reverse
end

@testitem "explicit target" begin
    # https://github.com/JuliaObjects/Accessors.jl/pull/55
    x = [1, 2, 3]
    x_orig = x
    @test (@set $(x)[2] = 100) == [1, 100, 3]
    @test (@set $(x[2]) = 100) == 100
    @test (@set $(x)[2] + 2 = 100) == [1, 98, 3]  # impossible without $
    @test (@set $(x[2]) + 2 = 100) == 98  # impossible without $
    @test x_orig === x == [1, 2, 3]

    @test (@reset $(x[2]) = 100) == 100
    @test x_orig === x == [1, 100, 3]
    y = @reset $(x)[2] = 200
    @test x_orig !== x === y == [1, 200, 3]
end

@testitem "flipped index" begin
    # https://github.com/JuliaObjects/Accessors.jl/pull/103
    obj = (a=2, b=nothing)
    lens = @o (4:10)[_.a]
    @test @inferred(set(obj, lens, 4)).a == 1
    @test_throws ArgumentError set(obj, lens, 12)
    Accessors.test_getset_laws(lens, obj, 5, 6)
    Accessors.test_modify_law(x -> x + 1, lens, obj)
end

@testitem "show" begin
    @test sprint(show, @o(_.a[∗].b[∗ₚ].c[2])) == "(@optic _.a[∗].b[∗ₚ].c[2])"
    @test sprint(show, @o(_[∗].b)) == "(@optic _[∗].b)"
    @test sprint(show, @o(_[∗ₚ])) == "∗ₚ"
    @test sprint(show, @o(atan(_...))) == "splat(atan)"  # Base, cannot change without piracy
    @test sprint(show, @o(atan(_.a...))) == "(@optic atan(_.a...))"
    @test sprint(show, @o(tuple(_, 1, 2))) == "(@optic tuple(_, 1, 2))"
    @test sprint(show, @o(sort(_, by=abs))) == "(@optic sort(_, by=abs))"
    @test sprint(show, @o(sort(_, 1, by=abs))) == "(@optic sort(_, 1, by=abs))"
    @test sprint(show, @o(_ |> keyed(∗))) == "keyed(∗)"
    @test sprint(show, @o(_.a |> enumerated(∗ₚ))) == "(@optic _.a |> enumerated(∗ₚ))"
    @test sprint(show, @o(_.a[∗ₚ] |> selfcontext() |> _.b)) == "(ᵢ(@optic _.b))ᵢ ∘ (@optic _.a[∗ₚ] |> selfcontext(identity))"
    @test sprint(show, @o(_.a[∗].b[∗ₚ].c[2]); context=:compact => true) == "_.a[∗].b[∗ₚ].c[2]"
    @test sprint(show, @o(_.a[∗ₚ] |> selfcontext() |> _.b); context=:compact => true) == "(_.b)ᵢ ∘ _.a[∗ₚ] |> selfcontext(identity)"
end