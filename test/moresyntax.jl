@testitem "and/or/..." begin
    @test (<(5) ⩓ >(1) ⩓ >(2))(3)
    @test (!(<(5) ⩓ >(1) ⩓ >(2)))(2)
    @test (<(5) ⩓ >(1) ⩔ >(2))(2)
    @test (<(5) ⩓ >(1) ⩔ >(2))(6)
    @test (!(<(5) ⩓ >(1) ⩔ >(2)))(0)
    @test (!(<(5) ⩓ (x->throw(""))))(6)
    @test (<(5) ⩔ (x->throw("")))(4)

    f = x->x+1
    # @test (@o _.a && 10 > 0) === (@o _.a) ⩓ (@o _.b > 0)
    @test (@o _.a || f(_.b) > 0) === (@o _.a) ⩔ (@o f(_.b) > 0)
    @test (@o _.a && _.b > 0) === (@o _.a) ⩓ (@o _.b > 0)
    @test (@o _.a || _.b > 0 && _.a < 1) === (@o _.a) ⩔ ((@o _.b > 0) ⩓ (@o _.a < 1))
    @test (@o 0 < f(_.a) ≤ 10) === (@o 0 < f(_.a)) ⩓ (@o f(_.a) ≤ 10)
end

@testitem "fixargs" begin
    using AccessorsExtra.Accessors: test_getset_laws

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

    o = @o sort.(_, by=abs)
    @test o([[-3, 1], [2, 0]]) == [[1, -3], [0, 2]]
    @test set([[-3, 1], [2, 0]], o, [[1, 2], [3, -4]]) == [[2, 1], [-4, 3]]

    o = @o atan.(_...)
    @test o(((1, 2), (3, 4))) == (atan(1, 2), atan(3, 4))
    test_getset_laws(o, [[1, 2], [3, 4]], [0.3, 0.4], [0.1, 0.2]; cmp=(≈))
    end

    @test_broken @eval (@o sort(_; by=identity))([-3, 1, 2, 0]) == [-3, 0, 1, 2]
    @test_broken @eval (@o sort(_; by=abs))([-3, 1, 2, 0]) == [0, 1, 2, -3]

    test_getset_laws((@o sort(_, rev=true)), [-3, 1, 2, 0], [40, 30, 20, 10], 4:-1:1)
    test_getset_laws((@o sort(_, by=abs)), [-3, 1, 2, 0], [10, -20, 30, 40], 1:4)
    test_getset_laws((@o sort(_, by=abs, rev=true)), [-3, 1, 2, 0], [10, -20, 30, 40]|>reverse, 1:4|>reverse)

    @test (@o atan(_...)) === splat(atan)
    @test (@o atan(reverse(_)...)) === splat(atan) ∘ reverse
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
    using AccessorsExtra: flat_concatoptic

    # XXX: some tests just test Accessors
    @test sprint(show, @o(_.a[∗].b[∗ₚ].c[2])) == "(@o _.a[∗].b[∗ₚ].c[2])"
    @test sprint(show, @o(_[∗].b)) == "(@o _[∗].b)"
    @test sprint(show, @o(_[∗ₚ])) == "(@o _[∗ₚ])"
    @test sprint(show, @o(atan(_...))) == "splat(atan)"  # Base, cannot change without piracy
    @test sprint(show, @o(atan(_.a...))) == "(@o atan(_.a...))"
    @test sprint(show, @o(tuple(_, 1, 2))) == "(@o tuple(_, 1, 2))"
    @test sprint(show, @o(sort(_, by=abs))) == "(@o sort(_, by=abs))"
    @test sprint(show, @o(sort(_, 1, by=abs))) == "(@o sort(_, 1, by=abs))"
    @test sprint(show, first ⩔ last) == "first ⩔ last"
    @test sprint(show, (@o _.a) ⩓ (@o last(_.b) > 1)) == "(@o _.a) ⩓ (@o last(_.b) > 1)"
    @test sprint(show, @o(_ |> keyed(∗))) == "keyed((@o _[∗]))"
    @test sprint(show, @o(_.a |> enumerated(∗ₚ))) == "(@o _.a |> enumerated((@o _[∗ₚ])))"
    @test sprint(show, @o(_.a[∗ₚ] |> selfcontext() |> _.b)) == "(ᵢ(@o _.b))ᵢ ∘ (@o _.a[∗ₚ] |> selfcontext(identity))"
    @test sprint(show, @o(_.a[∗].b[∗ₚ].c[2]); context=:compact => true) == "_.a[∗].b[∗ₚ].c[2]"
    @test sprint(show, @o(_.a[∗ₚ] |> selfcontext() |> _.b); context=:compact => true) == "(_.b)ᵢ ∘ _.a[∗ₚ] |> selfcontext(identity)"
    @test sprint(show, (@o _.a + _.b)) == "(@o _.a + _.b)"
    @test sprint(show, (@o _.a + _.b); context=:compact => true) == "_.a + _.b"

    @test sprint(show, @maybe _.a) == "(@maybe _.a)"
    @test sprint(show, @maybe _.a 0.2) == "(@maybe _.a 0.2)"
    @test sprint(show, (@maybe _.a); context=:compact => true) == "_.a?"
    @test sprint(show, (@maybe _.a 0.2); context=:compact => true) == "_.a || 0.2"

    @test sprint(show, (@osomething _.a 123)) == "(@osomething _.a 123)"
    @test sprint(show, (@o _.a) ∘ (@osomething _.a 123)) == "(@o _.a) ∘ (@osomething _.a 123)"
    @test sprint(show, (@osomething _.a 123) ∘ (@o _.a)) == "(@osomething _.a 123) ∘ (@o _.a)"
    @test sprint(show, (@osomething _.a 123); context=:compact => true) == "_.a || 123"
    @test sprint(show, (@o _.a) ∘ (@osomething _.a 123); context=:compact => true) == "_.a ∘ _.a || 123"

    @test map(flat_concatoptic((a=1, b=(2, 3)), (@o _.a exp(_.b[∗]))).optics) do o
        sprint(show, o; context=:compact => true)
    end == ("_.a", "exp(_.b[1])", "exp(_.b[2])")
end

@testitem "barebones string" begin
    using AccessorsExtra: barebones_string

    @test barebones_string(@o _.a[∗].b[∗ₚ].c[2]) == "a[∗].b[∗ₚ].c[2]"
    @test barebones_string(@o _[∗].b) == "[∗].b"
    @test barebones_string(@o _[∗ₚ]) == "[∗ₚ]"
    @test barebones_string(@o atan(_...)) == "atan(_...)"
    @test barebones_string(@o _ + 1) == "_ + 1"
    @test barebones_string(@o _) == "_"
    @test barebones_string(@o atan(_.a...)) == "atan(a...)"
    @test barebones_string(@o tuple(_, 1, 2)) == "tuple(_, 1, 2)"
    @test barebones_string(@o _ + 1 + 2) == "+(_, 1, 2)"
    @test barebones_string(@o sort(_, by=abs)) == "sort(_, by=abs)"
    @test barebones_string(@o sort(_, 1, by=abs)) == "sort(_, 1, by=abs)"
    @test barebones_string(@maybe _.a) == "a?"
    @test barebones_string(@maybe _.a 0.2) == "a || 0.2"
    @test barebones_string(@maybe _.a + _.b) == "a + b?"
    @test barebones_string(exp ∘ (@maybe _.a + _.b 0.2)) == "exp(a + b || 0.2)"
    @test barebones_string(Returns(123)) == "123"
    @test barebones_string(@osomething _.a 123) == "a || 123"
end

@testitem "split unit" begin
    using AccessorsExtra: _split_unitstr_from_optic
    using Unitful

    @test _split_unitstr_from_optic(identity) == (identity, nothing)
    @test _split_unitstr_from_optic(rad2deg) == (identity, "°")
    @test _split_unitstr_from_optic(@o rad2deg(_.a)) == ((@o _.a), "°")
    @test _split_unitstr_from_optic(@o ustrip(u"km", _.a)) == ((@o _.a), "km")

    @test _split_unitstr_from_optic(Int, identity) == (identity, nothing)
    @test _split_unitstr_from_optic(Int, rad2deg) == (identity, "°")
    @test _split_unitstr_from_optic((a=1,), @o rad2deg(_.a)) == ((@o _.a), "°")
    @test _split_unitstr_from_optic((a=1,), @o ustrip(u"km", _.a)) == ((@o _.a), "km")

    @test _split_unitstr_from_optic(ustrip) == ((@o _), nothing)
    @test _split_unitstr_from_optic(123, ustrip) == ((@o _), "")
    @test _split_unitstr_from_optic(123u"m", ustrip) == ((@o _), "m")
    @test _split_unitstr_from_optic((a=123u"m",), @o ustrip(_.a)) == ((@o _.a), "m")
    @test _split_unitstr_from_optic(typeof(123), ustrip) == ((@o _), "")
    @test _split_unitstr_from_optic(typeof(123u"m"), ustrip) == ((@o _), "m")
    @test _split_unitstr_from_optic(typeof((a=123u"m",)), @o ustrip(_.a)) == ((@o _.a), "m")

    @test _split_unitstr_from_optic(@o rad2deg(_.a |> enumerated(∗) |> _.b)) == ((@o _.a |> enumerated(∗) |> _.b), "°")
    @test _split_unitstr_from_optic((@o ustrip(u"km", _.a[∗])) |> enumerated) == ((@o _.a[∗]) |> enumerated, "km")
end
