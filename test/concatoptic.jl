@testitem "concat optics" begin
    @testset for o in (
        @o(_.a) ++ @o(_.b),
        @o(_.a, _.b),
        @o(_[(:a, :b)] |> Elements()),
    )
        obj = (a=1, b=2, c=3)
        @test getall(obj, o) === (1, 2)
        @test setall(obj, o, (3, 4)) === (a=3, b=4, c=3)
        @test modify(-, obj, o) === (a=-1, b=-2, c=3)
        Accessors.test_getsetall_laws(o, obj, (3, 4), (:a, :b))
    end

    @test (@o _.a _.b) ++ (@o _.c _.d) === @o _.a _.b _.c _.d
    @test (@o _.a _.b) ++ (@o _.c) === @o _.a _.b _.c
    @test (@o _.a _.b) ++ concat() ++ (@o _.c) === @o _.a _.b _.c
    @test (@o _.a _.b) === @o _.a _.b

    obj = (a=1, bs=((c=2, d=3), (c=4, d=5)))
    o = concat(a=@o(_.a), c=@o(first(_.bs) |> _.c))
    AccessorsExtra.@allinferred getall modify delete if VERSION >= v"1.10-"; :setall end begin
        @test getall(obj, o) === (a=1, c=2)
        @test setall(obj, o, (a="10", c="11")) === (a="10", bs=((c="11", d=3), (c=4, d=5)))
        @test setall(obj, o, (c="11", a="10")) === (a="10", bs=((c="11", d=3), (c=4, d=5)))
        @test modify(float, obj, o) === (a=1.0, bs=((c=2.0, d=3), (c=4, d=5)))
        @test delete(obj, o) === (bs=((d=3,), (c=4, d=5)),)
    end
    @test delete(obj, o) === (bs=((d=3,), (c=4, d=5)),)
    

    AccessorsExtra.@allinferred getall setall modify begin
        obj = (a=1, bs=((c=2, d=3), (c=4, d=5)))
        o = @o _.a  _.bs |> Elements() |> _.c
        @test getall(obj, o) === (1, 2, 4)
        @test setall(obj, o, (:a, :b, :c)) === (a=:a, bs=((c=:b, d=3), (c=:c, d=5)))
        @test modify(-, obj, o) === (a=-1, bs=((c=-2, d=3), (c=-4, d=5)))
        Accessors.test_getsetall_laws(o, obj, (3, 4, 5), (:a, :b, :c))

        o = @o(_ - 1) ∘ (@o _.a  _.bs |> Elements() |> _.c)
        @test getall(obj, o) === (0, 1, 3)
        @test modify(-, obj, o) === (a=1, bs=((c=0, d=3), (c=-2, d=5)))
        Accessors.test_getsetall_laws(o, obj, (3, 4, 5), (10, 20, 30))

        obj = (a=1, bs=[(c=2, d=3), (c=4, d=5)])
        o = @o _.a  _.bs |> Elements() |> _.c
        @test getall(obj, o) == [1, 2, 4]
        @test modify(-, obj, o) == (a=-1, bs=[(c=-2, d=3), (c=-4, d=5)])
    end
    @test setall(obj, o, (:a, :b, :c)) == (a=:a, bs=[(c=:b, d=3), (c=:c, d=5)])

    @test getall((1,2), ++()) === ()
    @test setall((1,2), ++(), ()) === (1,2)
    @test setall((1,2), AccessorsExtra.ConcatOptics((;)), (;)) === (1,2)
    @test getall((1,2), ++() ∘ identity) === ()
    @test setall((1,2), ++() ∘ identity, ()) === (1,2)
    @test setall((1,2), AccessorsExtra.ConcatOptics((;)) ∘ identity, (;)) === (1,2)
end

@testitem "construction edgecases" begin
    @test concat() === ConcatOptics(())
    @test concat(@o _.a) === @o _.a
    @test concat((@o _.a), (@o _.b)) === ConcatOptics(((@o _.a), (@o _.b)))
    @test concat(concat()) === ConcatOptics(())
    @test concat(concat(), concat()) === ConcatOptics(())
    @test concat((@o _.a), concat()) === @o _.a
    @test concat((@o _.a), concat((@o _.c), (@o _.d)), (@o _.b)) === ConcatOptics(((@o _.a), (@o _.c), (@o _.d), (@o _.b)))
end

@testitem "concat container" begin
    using StaticArrays
    using AccessorsExtra: insert

    AccessorsExtra.@allinferred o set modify begin
    o = @o (_.a.b, _.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (1, 3)
    @test set(m, o, (4, 5)) == (a=(b=4, c=2), c=5)
    @test modify(xs -> xs ./ sum(xs), m, o) == (a=(b=0.25, c=2), c=0.75)

    o = @o (x=_.a.b, y=_.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (x=1, y=3)
    @test set(m, o, (x=4, y=5)) == (a=(b=4, c=2), c=5)
    @test set(m, o, (y=5, x=4)) == (a=(b=4, c=2), c=5)
    @test modify(xs -> map(x -> x - xs.x, xs), m, o) == (a=(b=0, c=2), c=2)

    o = @o (_.a.b + 1, -_.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (2, -3)
    @test set(m, o, (4, 5)) == (a=(b=3, c=2), c=-5)
    @test modify(xs -> xs ./ sum(xs), m, o) == (a=(b=-3.0, c=2), c=-3.0)
    end
    
    o = @o SVector(_.a.b, _.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == SVector(1, 3)
    @test set(m, o, SVector(4, 5)) == (a=(b=4, c=2), c=5)
    @test modify(xs -> 2*xs, m, o) == (a=(b=2, c=2), c=6)
    @test delete(m, o) == (;a=(c=2,))
    @test insert((;a=(;), d=5), o, (1, 2)) == (a=(;b=1), d=5, c=2)

    o = @o Pair(_.a.b, _.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (1 => 3)
    @test set(m, o, 4 => 5) == (a=(b=4, c=2), c=5)

    o = @o _.a.b => _.c
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (1 => 3)
    @test set(m, o, 4 => 5) == (a=(b=4, c=2), c=5)
    
    o = @o [_.a.b, _.c]
    m = (a=(b=1, c=2), c=3)
    @test o(m) == [1, 3]
    @test set(m, o, [4, 5]) == (a=(b=4, c=2), c=5)
    @test modify(xs -> 2*xs, m, o) == (a=(b=2, c=2), c=6)
    
    # o = @o Dict("x" => _.a.b, "y" => _.c)
    # m = (a=(b=1, c=2), c=3)
    # @test o(m) == Dict("x" => 1, "y" => 3)
    # @test set(m, o, Dict("x" => 4, "y" => 5)) == (a=(b=4, c=2), c=5)
    # @test set(m, o, Dict("y" => 5, "x" => 4)) == (a=(b=4, c=2), c=5)

    o = @o (x=(u=_.a.b, v=_.c), y=_.a.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (x=(u=1, v=3), y=2)
    @test set(m, o, (x=(u=5, v=6), y=7)) == (a=(b=5, c=7), c=6)

    o = @o (x=[_.a.b, _.c], y=_.a.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (x=[1, 3], y=2)
    @test set(m, o, (x=[5, 6], y=7)) == (a=(b=5, c=7), c=6)
    @test delete(m, o) == (;a=(;))
    @test insert((;a=(;)), o, ([1,2], 3)) == (a=(b=1, c=3), c=2)
end

@testitem "concat container on structarrays" begin
    using StructArrays
    using FlexiMaps

    A = StructArray(a=StructArray(b=[1, 2]), c=[3, 4])
    @test mapview((@o (x=_.a.b, y=_.c)), A) === StructArray(x=A.a.b, y=A.c)
    @test A.a.b !== map((@o (x=_.a.b, y=_.c)), A).x == A.a.b
    @test mapview((@o (_.a.b, _.c)), A) === StructArray((A.a.b, A.c))
    @test A.a.b !== map((@o (_.a.b, _.c)), A).:1 == A.a.b
end

@testitem "flatten to concatoptic" begin
    using AccessorsExtra: tree_concatoptic, flat_concatoptic

    obj = (a=1, b=(2, 3))
    @testset for O in (obj, typeof(obj))
        @test tree_concatoptic(O, (@o _[∗ₚ][∗])) === (@o _.a[]) ++ (((@o _[1]) ++ (@o _[2])) ∘ (@o _.b))
        @test tree_concatoptic(O, (@o _[∗ₚ][∗] + 1)) === (@o _.a[] + 1) ++ (((@o _[1] + 1) ++ (@o _[2] + 1)) ∘ (@o _.b))
        @test tree_concatoptic(O, (@o _.a)) === @o _.a
        @test tree_concatoptic(O, (@o _.a + 1)) === @o _.a + 1
        @test tree_concatoptic(O, (@o _.b[∗] * 2)) === ((@o _[1] * 2) ++ (@o _[2] * 2)) ∘ (@o _.b)
        @test tree_concatoptic(O, (@o _.a + 1 _.b[∗] * 2)) === (@o _.a + 1) ++ (((@o _[1] * 2) ++ (@o _[2] * 2)) ∘ (@o _.b))
        @test tree_concatoptic(O, (@o _[]) ∘ (@o _.a)) === (@o _.a[])
        @test tree_concatoptic(O, ConcatOptics(((@o _[]),)) ∘ (@o _.a)) === (@o _.a[])

        @test flat_concatoptic(O, (@o _[∗ₚ][∗])) === (@o _.a[]) ++ (@o _.b[1]) ++ (@o _.b[2])
        @test flat_concatoptic(O, (@o _[∗ₚ][∗] + 1)) === (@o _.a[] + 1) ++ (@o _.b[1] + 1) ++ (@o _.b[2] + 1)
        @test flat_concatoptic(O, (@o _.a)) === @o _.a
        @test flat_concatoptic(O, (@o _.a + 1)) === @o _.a + 1
        @test flat_concatoptic(O, (@o _.b[∗] * 2)) === (@o _.b[1] * 2) ++ (@o _.b[2] * 2)
        @test flat_concatoptic(O, (@o _.a + 1 _.b[∗] * 2)) === (@o _.a + 1) ++ (@o _.b[1] * 2) ++ (@o _.b[2] * 2)
        @test flat_concatoptic(O, (@o _[]) ∘ (@o _.a)) === (@o _.a[])
    end

    @test tree_concatoptic(String, (@o _[∗ₚ])) === concat()
    @test flat_concatoptic(String, (@o _[∗ₚ])) === concat()

    @test tree_concatoptic(Nothing, (@o _[∗ₚ])) === concat()
    @test flat_concatoptic(Nothing, (@o _[∗ₚ])) === concat()

    @test tree_concatoptic(Nothing, (@o _[∗ₚ][∗ₚ])) === concat()
    @test flat_concatoptic(Nothing, (@o _[∗ₚ][∗ₚ])) === concat()

    o = tree_concatoptic(Union{Nothing, @NamedTuple{a::Int64, b::Float64}}, (@o _[∗ₚ]))
    @test getall(nothing, o) === ()
    @test getall((a=1, b=2.0), o) === (1, 2.0)

    o = tree_concatoptic(Union{Nothing, @NamedTuple{a::Union{Nothing, @NamedTuple{b::Int64, c::String}}}}, (@o _[∗ₚ][∗ₚ]))
    @test getall(nothing, o) === ()
    @test getall((a=nothing,), o) === ()
    @test getall((a=(b=1, c="2"),), o) === (1, "2")

    os = flat_concatoptic(Union{Nothing, @NamedTuple{a::Int64, b::Float64}}, (@o _[∗ₚ])) |> AccessorsExtra._optics
    @test os === ((@maybe _.a), (@maybe _.b))

    os = flat_concatoptic(Union{Nothing, @NamedTuple{a::Union{Nothing, @NamedTuple{b::Int64}}}}, (@o _[∗ₚ][∗ₚ])) |> AccessorsExtra._optics
    @test os === ((@maybe _.b) ∘ (@maybe _.a),)
end

@testitem "flatten with arrays" begin
    using AccessorsExtra: tree_concatoptic, ConcatOptics
    using StaticArrays

    struct U{T} <: FieldVector{1, T}
        u::T
    end

    struct UV{T} <: FieldVector{2, T}
        u::T
        v::T
    end

    @test tree_concatoptic(SVector{0, Int}, (@o _[∗])) == concat()
    @test tree_concatoptic(SVector{1, Int}, (@o _[∗])) == ConcatOptics(((@o _[1]),))
    @test tree_concatoptic(SVector{2, Int}, (@o _[∗])) == @o _[1] _[2]
    @test_broken tree_concatoptic(SVector{2, Int}, (@o _[∗ₚ])) == @o _.x _.y  # https://github.com/JuliaArrays/StaticArrays.jl/pull/1289
    @test tree_concatoptic(U{Float64}, (@o _[∗])) == ConcatOptics(((@o _[1]),))
    @test tree_concatoptic(U{Float64}, (@o _[∗ₚ])) == @o _.u
    @test tree_concatoptic(UV{Float64}, (@o _[∗])) == @o _[1] _[2]
    @test tree_concatoptic(UV{Float64}, (@o _[∗ₚ])) == @o _.u _.v

    @test tree_concatoptic(Vector{Int}, (@o _[∗ₚ])) == concat()
    @test tree_concatoptic(Matrix{Int}, (@o _[∗ₚ])) == concat()
    @test tree_concatoptic(Array{Int,3}, (@o _[∗ₚ])) == concat()
    @test tree_concatoptic(Vector{Int}, (@o _[∗])) == @o _[∗]
    @test tree_concatoptic(Matrix{Int}, (@o _[∗])) == @o _[∗]
    @test tree_concatoptic(Array{3, Int}, (@o _[∗])) == @o _[∗]
end
