using TestItems
using TestItemRunner
@run_package_tests

@testitem "flexix" begin
    using AccessorsExtra: FlexIx

    s = "abc"
    @test "adefxyz" == @set s[FlexIx(2:3)] = "defxyz"
    @test "adefbc" == @modify(x -> "def" * x, s[FlexIx(2:3)])
    v = [1, 2, 3]
    @test [1, 10, 11, 12] == @set v[FlexIx(2:3)] = [10, 11, 12]
    @test [1, 10, 2, 3] == @modify(x -> [10, x...], v[FlexIx(2:3)])
    v = (1, 2, 3)
    @test (1, 10, 11, 12) == @set v[FlexIx(2:3)] = (10, 11, 12)
    @test (1, 10, 2, 3) == @modify(x -> (10, x...), v[FlexIx(2:3)])
end

@testitem "modify-many" begin
    using Dictionaries
    using UnionCollections

    # function Dictionaries.checkindices(indices, inds::AbstractIndices)
    #     if !(inds ⊆ indices)
    #         short_ind = repr(indices, context=:limit => true)
    #         throw(IndexError("Indices $inds are not a subset of $short_ind"))
    #     end
    # end

    # Base.view(d::AbstractDictionary, inds::AbstractArray) = Dictionaries.Indexing.ViewArray{eltype(d), ndims(inds)}(@show(d), @show inds)

    const UnionDictionary = Base.get_extension(UnionCollections, :DictionariesExt).UnionDictionary

    AccessorsExtra.@allinferred modify begin
    @test modify(+, (1, 2.), ∗, (3, 4)) === (4, 6.)
    @test modify(+, (1, 2.), ∗, (a=3, b=4.)) === (4, 6.)
    @test modify(+, (1, 2.), ∗, [3, 4, 5]) === (4, 6.)
    @test modify(+, (x=1, y=2.), ∗, (3, 4.)) === (x=4, y=6.)
    @test modify(+, (x=1, y=2.), ∗, (a=3, b=4.)) === (x=4, y=6.)
    @test modify(+, (x=1, y=2.), ∗, [3, 4]) === (x=4, y=6.)
    @test modify(+, [1, 2], ∗, (3, 4, 5)) == [4, 6]
    @test modify(+, [1, 2], ∗, (a=3, b=4)) == [4, 6]
    @test modify(+, [1, 2], ∗, [3, 4]) == [4, 6]

    @test modify(+, (1, 2), ∗ₚ, (3, 4)) === (4, 6)
    @test modify(+, (x=1, y=2), ∗ₚ, (x=3, y=4, z=5)) === (x=4, y=6)
    @test modify(+, (x=1, y=2), ∗ₚ, (y=4, x=3, z=5)) === (x=4, y=6)
    # @test modify(+, (x=1, y=2), ∗ₚ, Dict(:y=>4, :x=>3, :z=>5)) === (x=4, y=6)
    # @test modify(+, (x=1, y=2), ∗ₚ, dictionary([:y=>4, :x=>3])) === (x=4, y=6)
    @test_throws Exception modify(+, (1, 2), ∗ₚ, (a=3, b=4))
    @test_throws Exception modify(+, (x=1, y=2), ∗ₚ, (3, 4))
    @test_throws Exception modify(+, (x=1, y=2), ∗ₚ, (a=3, b=4))

    @test modify(+, Dictionary([2, 3], [10, 20]), ∗, 1:5)::Dictionary == Dictionary([2, 3], [11, 22])
    # @test modify(+, Dictionary([2, 3], [10, 20]), keyed(∗), 1:5)::Dictionary == Dictionary([2, 3], [12, 23])
    @test modify(+, ArrayDictionary([2, 3], [10, 20]), ∗, 1:5)::ArrayDictionary == Dictionary([2, 3], [11, 22])
    # @test_broken modify(+, ArrayDictionary([2, 3], [10, 20]), keyed(∗), 1:5)::ArrayDictionary == Dictionary([2, 3], [12, 23])
    @test modify(+, unioncollection(Dictionary([2, 3], [10, 20])), ∗, 1:5)::UnionDictionary == Dictionary([2, 3], [11, 22])
    # @test modify(+, unioncollection(Dictionary([2, 3], [10, 20])), keyed(∗), 1:5)::UnionDictionary == Dictionary([2, 3], [12, 23])


    @test modify(+, (a=(1, 2), b=3), (@o _.a[∗]), (b=4, a=(5, 6))) === (a=(6, 8), b=3)
    @test modify(+, (a=(1, 2), b=3), (@optics _.a[∗] _.b), (b=4, a=(5, 6))) === (a=(6, 8), b=7)
    end
end

@testitem "function value setting" begin
    o = @o _("abc")
    @test o === AccessorsExtra.funcvallens("abc")
    @test o(reverse) == "cba"
    myrev = set(reverse, o, "!!!")
    @test myrev("abc") == "!!!"
    @test myrev("def") == "fed"

    @test (@o _([])) == AccessorsExtra.funcvallens([])
    x = []
    @test (@o _(x)) === AccessorsExtra.funcvallens(x)

    f = modify(uppercase, lowercase, first ∘ AccessorsExtra.FuncResult())
    @test f("abc") == "Abc"
    @test f("ABC") == "Abc"
    f = modify(uppercase, reverse, first ∘ AccessorsExtra.FuncArgument())
    @test f("abc") == "cbA"
    f = modify(uppercase, (func=lowercase, x=1), @o _.func |> AccessorsExtra.FuncResult() |> first)
    @test f.func("abc") == "Abc"
end

@testitem "regex" begin
    s = "name_2020_03_10.ext"
    o = @o match(r"(?<y>\d{4})_(\d{2})_(\d{2})", _).match
    @test o(s) == "2020_03_10"
    @test set(s, o, "2021_04_11") == "name_2021_04_11.ext"
    @test modify(d -> d + 20, s, @o match(r"(?<y>\d{4})_\d{2}_\d{2}", _)[:y] |> parse(Int, _)) == "name_2040_03_10.ext"
    @test modify(s -> "[$s]", s, @o match(r"(?<y>\d{4})_(\d{2})_(\d{2})", _)[∗]) == "name_[2020]_[03]_[10].ext"
    o = @o match(r"\d", _) |> If(!isnothing) |> _.match |> parse(Int, _)
    @test getall("a 1", o) == (1,)
    @test getall("a b", o) == ()
    @test modify(x -> x + 1, "a 1", o) == "a 2"
    @test modify(x -> x + 1, "a b", o) == "a b"

    s = "abc def dxyz"
    @test getall(s, @o eachmatch(r"d\w+", _)[∗].match) == ["def", "dxyz"]
    @test setall(s, @o(eachmatch(r"d\w+", _)[∗].match), ["aa", "ooo"]) == "abc aa ooo"
    @test modify(uppercase, s, @o eachmatch(r"d\w+", _)[∗].match) == "abc DEF DXYZ"
    @test modify(uppercase, s, @o eachmatch(r"d\w+", _)[∗].match |> first) == "abc Def Dxyz"

    @test getall(s, @o eachmatch(r"d(\w)\w+", _)[∗][1]) == ["e", "x"]
    @test getall(s, @o eachmatch(r"d(\w)\w+|(\w{10})", _)[∗][2]) == [nothing, nothing]
    @test getall(s, @o eachmatch(r"d(\w)\w\b|(\w{4})", _)[∗][1]) == ["e", nothing]
    # test composition when not at front/end:
    @test getall(s, @o _[begin:end] |> eachmatch(r"d(\w)\w+", _)[∗][1] |> _[1:1]) == ["e", "x"]
    @test setall(s, @o(eachmatch(r"d(\w)\w+", _)[∗][1]), ["ohoh", ""]) == "abc dohohf dyz"
    @test modify(m -> m^5, s, @o(eachmatch(r"d(\w)\w+", _)[∗][1])) == "abc deeeeef dxxxxxyz"

    @test modify(m -> m+1, "a: 1, b: 21", @o eachmatch(r"\d+", _)[∗].match |> parse(Int, _)) == "a: 2, b: 22"
    @test modify("fractions: 2/3, another 1/2, 5/2, all!", @o eachmatch(r"(\d+)/(\d+)", _)[∗]) do m
        f = parse(Int, m[1]) / parse(Int, m[2])
        first(string(f), 5)
    end == "fractions: 0.666, another 0.5, 2.5, all!"
    @test modify(
            "fractions: 2/3, another 0.5, 5/2, all!",
            @o eachmatch(r"(?<num>\d+)/(?<denom>\d+)|(?<frac>\d+\.\d+)", _)[∗] |> If(m -> !isnothing(m[:num]))) do m
        f = parse(Int, m[:num]) / parse(Int, m[:denom])
        first(string(f), 5)
    end == "fractions: 0.666, another 0.5, 2.5, all!"
    @test modify(
            "fractions: 2/3, another 0.5, 5/2, all!",
            @o eachmatch(r"(?<num>\d+)/(?<denom>\d+)|(?<frac>\d+\.\d+)", _)[∗][:denom] |> If(!isnothing) |> parse(Int, _)) do m
        m + 1
    end == "fractions: 2/4, another 0.5, 5/3, all!"
    @test modify(
            "fractions: 2/3, another 0.5, 5/2, all!",
            @o eachmatch(r"(?<num>\d+)/(?<denom>\d+)|(?<frac>\d+\.\d+)", _)[∗] |> If(m -> !isnothing(m[:num])) |> parse(Int, _[:denom])) do m
        m + 1
    end == "fractions: 2/4, another 0.5, 5/3, all!"
end

@testitem "maybe" begin
    AccessorsExtra.@allinferred modify set getall setall begin
    # @test set(1, something, 2) == 2
    # @test set(Some(1), something, 2) == Some(2)

    o = osomething(@o(_.a), @o(_.b))
    @test o((a=1, b=2)) == 1
    @test o((c=1, b=2)) == 2
    @test_throws "no optic" o((c=1,))
    @test set((a=1, b=2), o, 10) == (a=10, b=2)
    @test set((c=1, b=2), o, 10) == (c=1, b=10)
    @test_throws "no optic" set((c=1,), o, 10)


    @testset for o in ((@o get(_, :a, 0)), (@o get(() -> 0, _, :a)))
        @test o((a=1, b=2)) == 1
        @test o((c=1, b=2)) == 0
        @test set(Dict(:a=>1, :b=>2), o, 10) == Dict(:a=>10, :b=>2)
        @test set(Dict(:c=>1, :b=>2), o, 10) == Dict(:c=>1, :b=>2, :a=>10)
        @test modify(x->x+1, Dict(:a=>1, :b=>2), o) == Dict(:a=>2, :b=>2)
        @test modify(x->x+1, Dict(:c=>1, :b=>2), o) == Dict(:a=>1, :c=>1, :b=>2)
    end


    o = maybe(@o _[2]) ∘ @o(_.a)
    @test o((a=[1, 2],)) == 2
    @test o((a=[1],)) == nothing
    @test_throws Exception o((;))
    @test set((a=[1, 2],), o, 5) == (a=[1, 5],)
    @test set((a=[1],), o, 5) == (a=[1, 5],)
    @test_throws Exception set((;), o, 5)
    @test modify(x -> x+1, (a=[1, 2],), o) == (a=[1, 3],)
    @test modify(x -> x+1, (a=[1],), o) == (a=[1],)
    @test_throws Exception modify(x -> x+1, (;), o)
    @test modify(x -> nothing, (a=[1, 2],), o) == (a=[1],)
    @test modify(x -> nothing, (a=[1],), o) == (a=[1],)
    @test_throws Exception modify(x -> nothing, (;), o)

    for o in (maybe(@o _.a) ⨟ maybe(@o(_.b)), maybe(@o _.a.b))
        @test o((a=(b=1,),)) == 1
        @test o((a=(;),)) == nothing
        @test o((;)) == nothing
        @test set((a=(b=1,),), o, 5) == (a=(b=5,),)
        @test set((a=(;),), o, 5) == (a=(b=5,),)
        @test modify(x -> x+1, (a=(b=1,),), o) == (a=(b=2,),)
        @test modify(x -> x+1, (a=(;),), o) == (a=(;),)
        @test modify(x -> x+1, (;), o) == (;)
        @test modify(x -> nothing, (a=(b=1,),), o) == (a=(;),)
        @test modify(x -> nothing, (a=(;),), o) == (a=(;),)
        @test modify(x -> nothing, (;), o) == (;)

        @test getall((a=(b=1,),), o) == (1,)
        @test getall((a=(;),), o) == ()
        @test getall((;), o) == ()
        @test getall(nothing, o) == ()
        @test setall((a=(b=1,),), o, (5,)) == (a=(b=5,),)
        @test setall((a=(;),), o, ()) == (a=(;),)
        @test setall((;), o, ()) == (;)
        @test setall(nothing, o, ()) == nothing
    end

    for obj in ((5,), (a=5,), [5], Dict(1 => 5),)
        o = maybe(@o _[1])
        @test o(obj) == 5
        Accessors.test_getset_laws(o, obj, 10, 20)
    end

    for obj in ((), [],)
        o = maybe(@o _[1])
        @test o(obj) == nothing
        Accessors.test_getset_laws(o, obj, 10, 20)
    end

    for obj in ((;), Dict(),)
        o = maybe(@o _[:a])
        @test o(obj) == nothing
        Accessors.test_getset_laws(o, obj, 10, 20)
    end

    for o in [maybe(@o first(_).a), maybe(@o last(_).a)]
        for obj in ([(a=1,)], [(b=1,)], [(a=1,), (b=2,)], [(b=1,), (a=2,)],)
            Accessors.test_getset_laws(o, obj, 10, 20)
        end
        @test o([(a=1,)]) === 1
        @test o([]) === nothing
        @test o([(b=1,)]) === nothing
        @test modify(x -> x+1, [], o) == []
    end
    o = maybe(@o only(_).a)
    @test o([(a=1,)]) == 1
    @test o([(a=1,), (a=2,)]) === nothing

    o = maybe(@o last(_.a, 3))
    @test o((a=[1, 2, 3, 4, 5],)) == [3, 4, 5]
    @test o((a=[4, 5],)) == [4, 5]
    @test o((a=[],)) == []
    @test o((a=nothing,)) === nothing
    @test o(()) === nothing
    @test o(nothing) === nothing

    o = maybe(@o parse(Int, _))
    @test o("1") == 1
    @test o("a") === nothing
    @test o(nothing) === nothing
    @test modify(x -> x+1, "1", o) == "2"
    @test modify(x -> x+1, "a", o) == "a"
    @test set("1", o, 2) == "2"
    @test_broken set("a", o, 2) == "2"

    o = maybe(@o _.a) ∘ Elements()
    @test getall(((a=1,), (b=2,)), o) === (1,)
    @test getall(((b=2,),), o) === ()
    @test getall(((),), o) === ()
    @test modify(x -> x+1, ((a=1,), (b=2,)), o) === ((a=2,), (b=2,))
    @test modify(x -> nothing, ((a=1,), (b=2,)), o) === ((;), (b=2,))
    @test set(((a=1,), (b=2,)), o, 10) === ((a=10,), (b=2,))
    @test set(((a=1,), (b=2,)), o, nothing) === ((;), (b=2,))
    @test setall(((a=1,), (b=2,)), o, (10,)) === ((a=10,), (b=2,))
    @test_throws "tried to assign 0 elements to 1 destinations" setall(((a=1,), (b=2,)), o, ()) === ((a=10,), (b=2,))
    @test_throws "tried to assign 2 elements to 1 destinations" setall(((a=1,), (b=2,)), o, (10, 20)) === ((a=10,), (b=2,))

    o = @o _.a[2]
    @test oget((a=[1, 2, 3],), o, 123) == 2
    @test oget((;), o, 123) == 123
    @test oget((a=[1, 2, 3],), o) == 2
    @test oget((;), o) == nothing
    @test oget(Returns(123), (a=[1, 2, 3],), o) == 2
    @test oget(Returns(123), (;), o) == 123

    # specify default value in maybe() - semantic not totally clear...
    # also see get(...) above
    o = maybe(@o _[2]; default=10) ∘ @o(_.a)
    @test o((a=[1, 2],)) == 2
    @test o((a=[1],)) == 10
    @test_throws Exception o((;))
    # @test set((a=[1, 2],), o, 5) == (a=[1, 5],)
    # @test set((a=[1],), o, 5) == (a=[1, 5],)
    # @test_throws Exception set((;), o, 5)
    # @test modify(x -> x+1, (a=[1, 2],), o) == (a=[1, 3],)
    # @test_broken modify(x -> x+1, (a=[1],), o) == (a=[1, 11],)
    # @test_throws Exception modify(x -> x+1, (;), o)
    # @test modify(x -> nothing, (a=[1, 2],), o) == (a=[1],)
    # @test_broken modify(x -> 10, (a=[1, 2],), o) == (a=[1],)
    # @test modify(x -> 10, (a=[1],), o) == (a=[1],)
    # @test_throws Exception modify(x -> 10, (;), o)
    # @test modify(x -> nothing, (a=[1, 2],), o) == (a=[1],)
    # @test modify(x -> nothing, (a=[1],), o) == (a=[1],)
    # @test_throws Exception modify(x -> nothing, (;), o)
    end

    f = x -> 2*x
    @test (@maybe _.a) === maybe(@o _.a)
    @test (@maybe _.a[∗][2]) === maybe(@o _.a[∗][2])
    @test (@maybe exp(_.a[∗][2])) === maybe(@o exp(_.a[∗][2]))
    @test (@maybe _.a 10) === maybe(@o _.a; default=10)
    @test (@maybe f(_)) === maybe(f)

    x = (a=[1, 2],)
    @test (@oget x.a[2] 123) === 2
    @test (@oget x.a[3] 123) === 123
    @test (@oget x.a[2]) === 2
    @test (@oget x.a[3]) === nothing
    @test (@oget f(x.a[2]) 123) === 4

    @test osomething(@o(_.a)) === @osomething _.a
    @test osomething(@o(_.a), @o(_.b)) === @osomething _.a _.b
    @test osomething(@o(_.a), @o(f(_.b))) === @osomething _.a f(_.b)
end

@testitem "PartsOf" begin
    x = (a=((b=1,), (b=2,), (b=3,)), c=4)
    @test (@o _.a[∗].b |> PartsOf())(x) == (1, 2, 3)
    @test (@o _.a[∗].b |> PartsOf() |> length)(x) == 3
    o = @o _.a[∗].b
    @test getall(x, o) == (o ⨟ PartsOf())(x) == (1, 2, 3)
    o = (@o(_.a[∗].b) ++ @o(_.c)) ⨟ PartsOf()
    @test modify(reverse, x, o) == (a=((b=4,), (b=3,), (b=2,)), c=1)
    o = (@o(_.a[∗].b) ++ @o(_.c)) ⨟ @o(_ |> PartsOf() |> _[2])
    @test modify(x -> x*10, x, o) == (a=((b=1,), (b=20,), (b=3,)), c=4)
    o = (@o(_.a[∗].b) ++ @o(_.c)) ⨟ @o(_ |> PartsOf()) ⨟ @optics _[1] _[2]
    @test modify(x -> x*10, x, o) == (a=((b=10,), (b=20,), (b=3,)), c=4)
    @test modify(
        xs -> round.(Int, xs ./ sum(xs) .* 100),
        "Counts: 10, 15, and 25!",
        @o(eachmatch(r"\d+", _)[∗] |> parse(Int, _.match) |> PartsOf())
    ) == "Counts: 20, 30, and 50!"
end

@testitem "steps" begin
    @test get_steps([(a=1,)], @o first(_).a |> _ + 1) == [
        (o = first, g = (a = 1,)),
        (o = (@o _.a), g = 1),
        (o = @o(_ + 1), g = 2)
    ]
    @test get_steps([(a=1,)], @o first(_).b |> _ + 1 - 2) == [
        (o = first, g = (a = 1,)),
        (o = (@o _.b), g = AccessorsExtra.Thrown(ErrorException("type NamedTuple has no field b"))),
        (o = @o(_ + 1), g = nothing),
        (o = @o(_ - 2), g = nothing)
    ]

    o = logged(@o first(_).a |> _ + 1)
    @test o([(a=1,)]) == 2
    @test set([(a=1,)], o, 'y') == [(a='x',)]
    @test modify(-, [(a=1,)], o) == [(a=-3,)]
    o = logged(@o _[∗].a + 1)
    @test getall([(a=1,)], o) == [2]
    @test set([(a=1,)], o, 'y') == [(a='x',)]
    @test setall([(a=1,)], o, ['y']) == [(a='x',)]
    @test modify(-, [(a=1,)], o) == [(a=-3,)]
    o = logged(@optics _[∗].a + 1 _[1].a)
    @test getall([(a=1,)], o) == [2, 1]
    o = logged(@optic₊ (_[1].a + 1, _[1].a))
    @test o([(a=1,)]) == (2, 1)
end

@testitem "base optics" begin
    using StaticArrays

    x = [1, 2, 3]
    @test (@set (2 in $x) = false) == [1, 3]
    @test (@set (5 in $x) = true) == [1, 2, 3, 5]
    Accessors.test_getset_laws(@o(2 in _), [1,2,3], false, true)
    Accessors.test_getset_laws(@o(5 in _), [1,2,3], false, true)
    Accessors.test_getset_laws(@o(2 in _), Set([1,2,3]), false, true)
    Accessors.test_getset_laws(@o(5 in _), Set([1,2,3]), false, true)
end

@testitem "on get/set" begin
    obj = (a=1, b=2, tot=4)

    o = @o(_.a) ∘ onset(x -> @set x.tot = x.a + x.b)
    @test o(obj) === 1
    @test set(obj, o, 10) === (a=10, b=2, tot=12)
    @test setall(obj, @optics(_.a, _.b) ∘ onset(x -> @set x.tot = x.a + x.b), (10, 20)) === (a=10, b=20, tot=30)

    o = onget(x -> @set x.tot = x.a + x.b)
    @test o(obj) === (a=1, b=2, tot=3)
    @test set(obj, o, obj) === obj
end

@testitem "ConstrainedLens" begin
    obase = angle
    ore = modifying(real)(angle)
    oim = modifying(imag)(angle)
    x = 3 + 4im
    for o in (obase, ore, oim)
        @test o(x) == angle(x)
    end
    @test set(x, obase, 0) ≈ 5
    @test set(x, ore, 0) ≈ Inf + 4im
    @test set(x, oim, 0) ≈ 3
    @test set(x, obase, π/4) ≈ 5/√2 * (1 + 1im)
    @test set(x, ore, π/4) ≈ 4 * (1 + 1im)
    @test set(x, oim, π/4) ≈ 3 * (1 + 1im)
end

@testitem "getfield" begin
    t = (x=1, y=2.)
    @test set(t, @o(getfield(_, :x)), 10) === (x=10, y=2.)
    @test set(t, @o(getfield(_, :x)), :hello) === (x=:hello, y=2.)
    @test (@inferred set(t, @o(getfield(_, Val(:x))), 10)) === (x=10, y=2.)
    @test (@inferred set(t, @o(getfield(_, Val(:x))), :hello)) === (x=:hello, y=2.)
    @test_throws Exception set(t, @o(getfield(_, :z)), 3)
    
    struct S{T}
        x::T

        S(x) = new{typeof(x)}(10*x)
    end

    s = S(2)
    @test s.x == 20
    @test (@set s.x = 10).x == 100
    @test @inferred set(s, (@o getfield(_, :x)), 10).x === 10
    @test @inferred set(s, (@o getfield(_, :x)), 10.0).x === 10.0

    struct U{T}
        x::T
        y::Real

        U(x, y) = new{typeof(x)}(10*x, y+1)
    end

    u = U(2, 3)
    @test u.x === 20
    @test u.y === 4
    u2 = set(u, (@o getfield(_, :x)), 10)
    @test u2.x === 10
    @test u2.y === 4
    u2 = set(u, (@o getfield(_, :x)), 1.5)
    @test u2.x === 1.5
    @test u2.y === 4

    struct W{T}
        x::T
    end
    W(x) = W{Float64}(x)

    w = W(2)
    @test w.x === 2.0
    @test_broken set(w, (@o getfield(_, :x)), 10).x === 10.0

    struct V{T,N}
        x::T
    end
    V(x) = V{typeof(x), x}(x)

    v = V(2)
    @test v.x === 2
    @test set(v, (@o getfield(_, :x)), 10).x === 10
end

@testitem "view" begin
    A = [1, 2]
    @test set(A, @o(view(_, 2)[]), 10) === A == [1, 10]
    @test modify(-, A, @o(view(_, 2)[] + 1)) === A == [1, -12]

    Accessors.test_getset_laws(@o(view(_, 2)[]), [1, 2], 5, -1)
    Accessors.test_getset_laws(@o(view(_, 1:2)), [1, 2], 1:2, 5:6)

    A = [1, 2, (a=3, b=4)]
    @test set(A, @o(view(_, 1:2)), [-2, -3]) === A == [-2, -3, (a=3, b=4)]
    @test @modify(x -> 2x, A |> view(_, 1:2)) === A == [-4, -6, (a=3, b=4)]
    @test @modify(x -> x + 1, A |> view(_, 1:2) |> Elements()) === A == [-3, -5, (a=3, b=4)]
end

@testitem "eachslice" begin
    using InverseFunctions

    A = [1 2 3; 4 5 6]
    InverseFunctions.test_inverse(@o(eachslice(_, dims=1)), A; compare=(==))
    InverseFunctions.test_inverse(@o(eachslice(_, dims=2)), A; compare=(==))
    InverseFunctions.test_inverse(@o(eachslice(_, dims=2, drop=true)), A; compare=(==))
    InverseFunctions.test_inverse(@o(eachslice(_, dims=2, drop=false)), A; compare=(==))

    InverseFunctions.test_inverse(eachrow, A; compare=(==))
    InverseFunctions.test_inverse(eachcol, A; compare=(==))
    # InverseFunctions.test_inverse(eachrow, A[1, :]; compare=(==))
    # InverseFunctions.test_inverse(eachcol, A[1, :]; compare=(==))

    @test @modify(x -> x / sum(x), A |> eachslice(_, dims=1)[∗]) == [1/6 2/6 3/6; 4/15 5/15 6/15]
    @test @modify(x -> x / sum(x), A |> eachslice(_, dims=2)[∗]) == [1/5 2/7 3/9; 4/5 5/7 6/9]

    A = reshape(1:24, 2, 1, 3, 4)
    for d in 1:4
        InverseFunctions.test_inverse(@o(eachslice(_, dims=d)), A; compare=(==))
        InverseFunctions.test_inverse(@o(eachslice(_, dims=d, drop=true)), A; compare=(==))
        InverseFunctions.test_inverse(@o(eachslice(_, dims=d, drop=false)), A; compare=(==))
    end
end

@testitem "getindex inverse" begin
    using InverseFunctions

    InverseFunctions.test_inverse(Base.Fix1(getindex, [4, 5, 6]), 2)
    InverseFunctions.test_inverse(Base.Fix1(getindex, Dict(2 => 123, 3 => 456)), 2)
end

@testitem "ranges" begin
    r = 1:10
    @test -5:10 === @set first(r) = -5
    @test 1:15 === @set last(r) = 15

    r = Base.OneTo(10)
    @test Base.OneTo(19) === @set length(r) = 19
    @test -5:10 === @set first(r) = -5
    @test Base.OneTo(15) === @set last(r) = 15
end

@testitem "keys, values, pairs" begin
    using OffsetArrays
    using Dictionaries

    # ds = Dict(:a => 1:10,:b => 2:11)
    # delete(If) not possible? need Filtered(cond) == If(cond) ∘ Elements()
    # @test @delete ds |> values(_)[∗] |> If(x -> any(>=(5), x))
    # @test @delete ds |> values(_)[∗][∗] |> If(>=(5))

    # @test modify(b -> b < 15 ? b : nothing, data, @o(_[∗].bs |> Wither())) == [(a = 1, bs = [10, 11, 12]), (a = 2, bs = Nothing[])]
    # @test modify(b -> b < 15 ? b : nothing, data, @o _ |> Wither() |> _.bs |> Wither()) == [(a = 1, bs = [10, 11, 12])]

    AccessorsExtra.@allinferred modify begin
        T = (4, 5, 6)
        @test (8, 10, 12) === modify(x -> 2x, T, @o values(_)[∗])
        @test (5, 7, 9) === modify(((i, x),) -> i => i + x, T, @o pairs(_)[∗])
        @test_throws AssertionError @modify(((i, x),) -> (i+1) => i + x, T |> pairs(_)[∗])
        
        T = (a=4, b=5, c=6)
        @test (a=8, b=10, c=12) === modify(x -> 2x, T, @o values(_)[∗])
        @test (aa=4, bb=5, cc=6) === modify(x -> Symbol(x, x), (a=4, b=5, c=6), @o keys(_)[∗])  broken=VERSION < v"1.10-"
        @test (a=(:a, 8), b=(:b, 10), c=(:c, 12)) === modify(((i, x),) -> i => (i, 2x), T, @o pairs(_)[∗])
        
        A = [4, 5, 6]
        @test [8, 10, 12] == modify(x -> 2x, A, @o values(_)[∗])
        @test [5, 7, 9] == modify(((i, x),) -> i => i + x, A, @o pairs(_)[∗])
        @test [1, 2, 3] == set(A, values, [1, 2, 3])
        @test [6, 5, 4] == modify(reverse, A, values)
        
        A = OffsetArray([4, 5, 6], -1:1)
        @test OffsetArray([8, 10, 12], -1:1) == modify(x -> 2x, A, @o values(_)[∗])
        @test OffsetArray([3, 5, 7], -1:1) == modify(((i, x),) -> i => i + x, A, @o pairs(_)[∗])
        @test_broken OffsetArray([1, 2, 3], -1:1) == set(A, values, [1, 2, 3])  # XXX: should it work?
        @test OffsetArray([6, 5, 4], -1:1) == modify(reverse, A, values)

        D = Dict(4 => 5, 6 => 7)
        @test Dict(4 => 6, 6 => 8) == modify(x -> x+1, D, @o values(_)[∗])
        @test Dict(5 => 5, 7 => 7) == modify(x -> x+1, D, @o keys(_)[∗])
        @test Dict(8 => 9, 12 => 13) == modify(((i, x),) -> 2i => i + x, D, @o pairs(_)[∗])

        D = dictionary([4 => 5, 6 => 7])
        @test dictionary([4 => 6, 6 => 8]) == modify(x -> x+1, D, @o values(_)[∗])
        @test dictionary([5 => 5, 7 => 7]) == modify(x -> x+1, D, @o keys(_)[∗])
        @test dictionary([8 => 9, 12 => 13]) == modify(((i, x),) -> 2i => i + x, D, @o pairs(_)[∗])
        @test_broken dictionary([4 => 7, 6 => 5]) == modify(reverse, D, values)
        @test_broken dictionary([4 => 1, 6 => 2]) == set(D, values, [1, 2])

        D = ArrayDictionary([4, 6], [5, 7])
        @test dictionary([4 => 6, 6 => 8]) == modify(x -> x+1, D, @o values(_)[∗])
        @test dictionary([5 => 5, 7 => 7]) == modify(x -> x+1, D, @o keys(_)[∗])
        @test_broken dictionary([4 => 7, 6 => 5]) == modify(reverse, D, values)
        @test_broken dictionary([4 => 1, 6 => 2]) == set(D, values, [1, 2])
    end
    @test (aa=4, bb=5, cc=6) === modify(x -> Symbol(x, x), (a=4, b=5, c=6), @o keys(_)[∗])
end

@testitem "_" begin
    import CompatHelperLocal as CHL
    CHL.@check()

    using Aqua
    Aqua.test_all(AccessorsExtra, piracies=false, ambiguities=false)
end
