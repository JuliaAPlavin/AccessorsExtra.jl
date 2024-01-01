using TestItems
using TestItemRunner
@run_package_tests


@testitem "concat optics" begin
    @testset for o in (
        @optic(_.a) ++ @optic(_.b),
        @optics(_.a, _.b),
        @optic(_[(:a, :b)] |> Elements()),
    )
        obj = (a=1, b=2, c=3)
        @test getall(obj, o) === (1, 2)
        @test setall(obj, o, (3, 4)) === (a=3, b=4, c=3)
        @test modify(-, obj, o) === (a=-1, b=-2, c=3)
        Accessors.test_getsetall_laws(o, obj, (3, 4), (:a, :b))
    end

    AccessorsExtra.@allinferred getall modify if VERSION >= v"1.10-"; :setall end begin
        obj = (a=1, bs=((c=2, d=3), (c=4, d=5)))
        o = concat(a=@optic(_.a), c=@optic(first(_.bs) |> _.c))
        @test getall(obj, o) === (a=1, c=2)
        @test setall(obj, o, (a="10", c="11")) === (a="10", bs=((c="11", d=3), (c=4, d=5)))
        @test setall(obj, o, (c="11", a="10")) === (a="10", bs=((c="11", d=3), (c=4, d=5)))
        @test modify(-, obj, o) === (a=-1, bs=((c=-2, d=3), (c=4, d=5)))
    end

    AccessorsExtra.@allinferred getall setall modify begin
        obj = (a=1, bs=((c=2, d=3), (c=4, d=5)))
        o = @optics _.a  _.bs |> Elements() |> _.c
        @test getall(obj, o) === (1, 2, 4)
        @test setall(obj, o, (:a, :b, :c)) === (a=:a, bs=((c=:b, d=3), (c=:c, d=5)))
        @test modify(-, obj, o) === (a=-1, bs=((c=-2, d=3), (c=-4, d=5)))
        Accessors.test_getsetall_laws(o, obj, (3, 4, 5), (:a, :b, :c))

        o = @optic(_ - 1) ∘ (@optics _.a  _.bs |> Elements() |> _.c)
        @test getall(obj, o) === (0, 1, 3)
        @test modify(-, obj, o) === (a=1, bs=((c=0, d=3), (c=-2, d=5)))
        Accessors.test_getsetall_laws(o, obj, (3, 4, 5), (10, 20, 30))

        obj = (a=1, bs=[(c=2, d=3), (c=4, d=5)])
        o = @optics _.a  _.bs |> Elements() |> _.c
        @test getall(obj, o) == [1, 2, 4]
        @test modify(-, obj, o) == (a=-1, bs=[(c=-2, d=3), (c=-4, d=5)])
    end
    @test setall(obj, o, (:a, :b, :c)) == (a=:a, bs=[(c=:b, d=3), (c=:c, d=5)])
end

@testitem "concat container" begin
    using StaticArrays

    o = @optic₊ (_.a.b, _.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (1, 3)
    @test set(m, o, (4, 5)) == (a=(b=4, c=2), c=5)
    @test modify(xs -> xs ./ sum(xs), m, o) == (a=(b=0.25, c=2), c=0.75)

    o = @optic₊ (x=_.a.b, y=_.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (x=1, y=3)
    @test set(m, o, (x=4, y=5)) == (a=(b=4, c=2), c=5)
    @test set(m, o, (y=5, x=4)) == (a=(b=4, c=2), c=5)
    @test modify(xs -> map(x -> x - xs.x, xs), m, o) == (a=(b=0, c=2), c=2)
    
    o = @optic₊ SVector(_.a.b, _.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == SVector(1, 3)
    @test set(m, o, SVector(4, 5)) == (a=(b=4, c=2), c=5)
    @test modify(xs -> 2*xs, m, o) == (a=(b=2, c=2), c=6)

    o = @optic₊ Pair(_.a.b, _.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (1 => 3)
    @test set(m, o, 4 => 5) == (a=(b=4, c=2), c=5)
    
    o = @optic₊ [_.a.b, _.c]
    m = (a=(b=1, c=2), c=3)
    @test o(m) == [1, 3]
    @test set(m, o, [4, 5]) == (a=(b=4, c=2), c=5)
    @test modify(xs -> 2*xs, m, o) == (a=(b=2, c=2), c=6)
    
    o = @optic₊ Dict("x" => _.a.b, "y" => _.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == Dict("x" => 1, "y" => 3)
    @test set(m, o, Dict("x" => 4, "y" => 5)) == (a=(b=4, c=2), c=5)
    @test set(m, o, Dict("y" => 5, "x" => 4)) == (a=(b=4, c=2), c=5)
end

@testitem "shorter forms" begin
    o = @optic(_.a[∗].b[∗ₚ].c[2])
    @test o === @optic(_.a |> Elements() |> _.b |> Properties() |> _.c[2])
    @test sprint(show, o) == "(@optic _.a[∗].b[∗ₚ].c[2])"
end

@testitem "function value setting" begin
    # o = @optic _("abc")
    o = AccessorsExtra.funcvallens("abc")
    @test o(reverse) == "cba"
    myrev = set(reverse, o, "!!!")
    @test myrev("abc") == "!!!"
    @test myrev("def") == "fed"

    f = modify(uppercase, lowercase, first ∘ AccessorsExtra.FuncResult())
    @test f("abc") == "Abc"
    @test f("ABC") == "Abc"
    f = modify(uppercase, reverse, first ∘ AccessorsExtra.FuncArgument())
    @test f("abc") == "cbA"
    f = modify(uppercase, (func=lowercase, x=1), @optic _.func |> AccessorsExtra.FuncResult() |> first)
    @test f.func("abc") == "Abc"
end

@testitem "regex" begin
    s = "name_2020_03_10.ext"
    o = @optic match(r"(?<y>\d{4})_(\d{2})_(\d{2})", _).match
    @test o(s) == "2020_03_10"
    @test set(s, o, "2021_04_11") == "name_2021_04_11.ext"
    @test modify(d -> d + 20, s, @optic match(r"(?<y>\d{4})_\d{2}_\d{2}", _)[:y] |> parse(Int, _)) == "name_2040_03_10.ext"
    @test modify(s -> "[$s]", s, @optic match(r"(?<y>\d{4})_(\d{2})_(\d{2})", _)[∗]) == "name_[2020]_[03]_[10].ext"
    o = @optic match(r"\d", _) |> If(!isnothing) |> _.match |> parse(Int, _)
    @test getall("a 1", o) == (1,)
    @test getall("a b", o) == ()
    @test modify(x -> x + 1, "a 1", o) == "a 2"
    @test modify(x -> x + 1, "a b", o) == "a b"

    s = "abc def dxyz"
    @test getall(s, @optic eachmatch(r"d\w+", _)[∗].match) == ["def", "dxyz"]
    @test setall(s, @optic(eachmatch(r"d\w+", _)[∗].match), ["aa", "ooo"]) == "abc aa ooo"
    @test modify(uppercase, s, @optic eachmatch(r"d\w+", _)[∗].match) == "abc DEF DXYZ"
    @test modify(uppercase, s, @optic eachmatch(r"d\w+", _)[∗].match |> first) == "abc Def Dxyz"

    @test getall(s, @optic eachmatch(r"d(\w)\w+", _)[∗][1]) == ["e", "x"]
    @test getall(s, @optic eachmatch(r"d(\w)\w+|(\w{10})", _)[∗][2]) == [nothing, nothing]
    @test getall(s, @optic eachmatch(r"d(\w)\w\b|(\w{4})", _)[∗][1]) == ["e", nothing]
    # test composition when not at front/end:
    @test getall(s, @optic _[begin:end] |> eachmatch(r"d(\w)\w+", _)[∗][1] |> _[1:1]) == ["e", "x"]
    @test setall(s, @optic(eachmatch(r"d(\w)\w+", _)[∗][1]), ["ohoh", ""]) == "abc dohohf dyz"
    @test modify(m -> m^5, s, @optic(eachmatch(r"d(\w)\w+", _)[∗][1])) == "abc deeeeef dxxxxxyz"

    @test modify(m -> m+1, "a: 1, b: 21", @optic eachmatch(r"\d+", _)[∗].match |> parse(Int, _)) == "a: 2, b: 22"
    @test modify("fractions: 2/3, another 1/2, 5/2, all!", @optic eachmatch(r"(\d+)/(\d+)", _)[∗]) do m
        f = parse(Int, m[1]) / parse(Int, m[2])
        first(string(f), 5)
    end == "fractions: 0.666, another 0.5, 2.5, all!"
    @test modify(
            "fractions: 2/3, another 0.5, 5/2, all!",
            @optic eachmatch(r"(?<num>\d+)/(?<denom>\d+)|(?<frac>\d+\.\d+)", _)[∗] |> If(m -> !isnothing(m[:num]))) do m
        f = parse(Int, m[:num]) / parse(Int, m[:denom])
        first(string(f), 5)
    end == "fractions: 0.666, another 0.5, 2.5, all!"
    @test modify(
            "fractions: 2/3, another 0.5, 5/2, all!",
            @optic eachmatch(r"(?<num>\d+)/(?<denom>\d+)|(?<frac>\d+\.\d+)", _)[∗][:denom] |> If(!isnothing) |> parse(Int, _)) do m
        m + 1
    end == "fractions: 2/4, another 0.5, 5/3, all!"
    @test modify(
            "fractions: 2/3, another 0.5, 5/2, all!",
            @optic eachmatch(r"(?<num>\d+)/(?<denom>\d+)|(?<frac>\d+\.\d+)", _)[∗] |> If(m -> !isnothing(m[:num])) |> parse(Int, _[:denom])) do m
        m + 1
    end == "fractions: 2/4, another 0.5, 5/3, all!"
end

@testitem "maybe" begin
    # @test set(1, something, 2) == 2
    # @test set(Some(1), something, 2) == Some(2)

    # get(...) - needs Base.Fix3

    o = maybe(@optic _[2]) ∘ @optic(_.a)
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

    o = maybe(@optic _.a) ⨟ maybe(@optic(_.b))
    @test o((a=(b=1,),)) == 1
    @test o((a=(;),)) == nothing
    @test o((;)) == nothing
    @test set((a=(b=1,),), o, 5) == (a=(b=5,),)
    @test set((a=(;),), o, 5) == (a=(b=5,),)
    @test_broken set((;), o, 5) == (a=(b=5,),)
    @test modify(x -> x+1, (a=(b=1,),), o) == (a=(b=2,),)
    @test modify(x -> x+1, (a=(;),), o) == (a=(;),)
    @test modify(x -> x+1, (;), o) == (;)
    @test modify(x -> nothing, (a=(b=1,),), o) == (a=(;),)
    @test modify(x -> nothing, (a=(;),), o) == (a=(;),)
    @test modify(x -> nothing, (;), o) == (;)

    for obj in ((5,), (a=5,), [5], Dict(1 => 5),)
        o = maybe(@optic _[1])
        @test o(obj) == 5
        Accessors.test_getset_laws(o, obj, 10, 20)
    end

    for obj in ((), [],)
        o = maybe(@optic _[1])
        @test o(obj) == nothing
        Accessors.test_getset_laws(o, obj, 10, 20)
    end

    for obj in ((;), Dict(),)
        o = maybe(@optic _[:a])
        @test o(obj) == nothing
        Accessors.test_getset_laws(o, obj, 10, 20)
    end

    # o = maybe(@optic _[2]; default=10) ∘ @optic(_.a)
    # @test o((a=[1, 2],)) == 2
    # @test o((a=[1],)) == 10
    # @test_throws Exception o((;))
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

@testitem "recursive" begin
    or = RecursiveOfType(out=(Number,), recurse=(Tuple, Vector, NamedTuple), optic=Elements())
    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx")))
    o = unrecurcize(or, typeof(m))
    @test getall(m, or) == (1, 1, 3)
    @test modify(x->x+10, m, or) == (a=11, bs=((c=11, d="2"), (c=13, d="xxx")))
    @test @inferred(getall(m, o)) == getall(m, or)
    @test @inferred(modify(x->x+10, m, o)) == modify(x->x+10, m, or)

    m = (a=1, bs=[(c=1, d="2"), (c=3, d="xxx")])
    o = unrecurcize(or, typeof(m))
    @test getall(m, or) == [1, 1, 3]
    @test modify(x->x+10, m, or) == (a=11, bs=[(c=11, d="2"), (c=13, d="xxx")])
    @test @inferred(getall(m, o)) == getall(m, or)
    @test @inferred(modify(x->x+10, m, o)) == modify(x->x+10, m, or)

    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx")))
    or = RecursiveOfType(out=(NamedTuple,), recurse=(Tuple, Vector, NamedTuple), optic=Elements())
    o = unrecurcize(or, typeof(m))
    @test getall(m, or) == ((c = 1, d = "2"), (c = 3, d = "xxx"), m)
    @test modify(Dict ∘ pairs, m, or) == Dict(:a => 1, :bs => (Dict(:d => "2", :c => 1), Dict(:d => "xxx", :c => 3)))
    @test_broken @inferred(getall(m, o)) == getall(m, or)
    @test getall(m, o) == getall(m, or)
    @test_broken @inferred(modify(Dict ∘ pairs, m, o)) == modify(Dict ∘ pairs, m, or)
    @test modify(Dict ∘ pairs, m, o) == modify(Dict ∘ pairs, m, or)

    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx", e=((;),))))
    o = unrecurcize(or, typeof(m))
    @test getall(m, or) == ((c = 1, d = "2"), (;), (c = 3, d = "xxx", e = ((;),)), (a = 1, bs = ((c = 1, d = "2"), (c = 3, d = "xxx", e = ((;),)))))
    @test getall(m, o) == getall(m, or)
end

@testitem "indexed" begin
    o = @optic(_.b)ᵢ ⨟ keyed(Elements()) ⨟ @optic(_.a)ᵢ
    @test modify(((i, v),) -> i => v, (a=1, b=((a='a',), (a='b',), (a='c',))), o) == (a=1, b=((a=1=>'a',), (a=2=>'b',), (a=3=>'c',)))
    @test modify(((i, v),) -> i => v, (a=1, b=[(a='a',), (a='b',), (a='c',)]), o) == (a=1, b=[(a=1=>'a',), (a=2=>'b',), (a=3=>'c',)])
    @test modify(
        wix -> wix.i => wix.v,
        (a=1, b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        keyed(@optic(_.a)) ++ keyed(@optic(_.b)) ⨟ @optic(_[∗].a)ᵢ
    ) == (a=:a=>1, b=(x=(a=:b=>'a',), y=(a=:b=>'b',), z=(a=:b=>'c',)))
    @test modify(
        wix -> wix.i => wix.v,
        (a=1, b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        @optic(_.b)ᵢ ⨟ keyed(Elements()) ⨟ Elements()ᵢ
    ) == (a=1, b=(x=(a=:x=>'a',), y=(a=:y=>'b',), z=(a=:z=>'c',)))

    @test modify(
        wix -> wix.v / wix.i.total,
        ((x=5, total=10,), (x=2, total=20,), (x=3, total=8,)),
        Elements() ⨟ selfindexed() ⨟ @optic(_.x)ᵢ
    ) == ((x=0.5, total=10,), (x=0.1, total=20,), (x=0.375, total=8,))
    @test modify(
        wix -> wix.v / wix.i,
        ((x=5, total=10,), (x=2, total=20,), (x=3, total=8,)),
        Elements() ⨟ selfindexed(r -> r.total) ⨟ @optic(_.x)ᵢ
    ) == ((x=0.5, total=10,), (x=0.1, total=20,), (x=0.375, total=8,))

    @test modify(
        wix -> "$(wix.v.match)_$(wix.i)",
        "abc def 5 x y z 123",
        @optic(eachmatch(r"\w+", _)) ⨟ enumerated(Elements())
    ) == "abc_1 def_2 5_3 x_4 y_5 z_6 123_7"
    @test modify(
        wix -> wix.v + wix.i,
        "abc def 5 x y z 123",
        @optic(eachmatch(r"\d+", _)) ⨟ enumerated(Elements()) ⨟ @optic(parse(Int, _.match))ᵢ
    ) == "abc def 6 x y z 125"
    @test modify(
        wix -> "$(wix.i):$(wix.v)",
        "2022-03-15",
        @optic(match(r"(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})", _)) ⨟ keyed(Elements())
    ) == "y:2022-m:03-d:15"
end

@testitem "All()" begin
    o = @optic _.a[∗].b
    x = (a=((b=1,), (b=2,), (b=3,)), c=4)
    @test getall(x, o) == (o ⨟ All())(x) == (1, 2, 3)
    o = (@optic(_.a[∗].b) ++ @optic(_.c)) ⨟ All()
    @test modify(reverse, x, o) == (a=((b=4,), (b=3,), (b=2,)), c=1)
    o = (@optic(_.a[∗].b) ++ @optic(_.c)) ⨟ @optic(_ |> All() |> _[2])
    @test modify(x -> x*10, x, o) == (a=((b=1,), (b=20,), (b=3,)), c=4)
    o = (@optic(_.a[∗].b) ++ @optic(_.c)) ⨟ @optic(_ |> All()) ⨟ @optics _[1] _[2]
    @test modify(x -> x*10, x, o) == (a=((b=10,), (b=20,), (b=3,)), c=4)
    @test modify(
        xs -> round.(Int, xs ./ sum(xs) .* 100),
        "Counts: 10, 15, and 25!",
        @optic(eachmatch(r"\d+", _)[∗] |> parse(Int, _.match) |> All())
    ) == "Counts: 20, 30, and 50!"
end

@testitem "steps" begin
    @test get_steps([(a=1,)], @optic first(_).a |> _ + 1) == [
        (o = first, g = (a = 1,)),
        (o = (@optic _.a), g = 1),
        (o = @optic(_ + 1), g = 2)
    ]
    @test get_steps([(a=1,)], @optic first(_).b |> _ + 1 - 2) == [
        (o = first, g = (a = 1,)),
        (o = (@optic _.b), g = AccessorsExtra.Thrown(ErrorException("type NamedTuple has no field b"))),
        (o = @optic(_ + 1), g = nothing),
        (o = @optic(_ - 2), g = nothing)
    ]

    o = logged(@optic first(_).a |> _ + 1)
    @test o([(a=1,)]) == 2
    @test set([(a=1,)], o, 'y') == [(a='x',)]
    @test modify(-, [(a=1,)], o) == [(a=-3,)]
    o = logged(@optic _[∗].a + 1)
    @test getall([(a=1,)], o) == [2]
    @test set([(a=1,)], o, 'y') == [(a='x',)]
    @test setall([(a=1,)], o, ['y']) == [(a='x',)]
    @test modify(-, [(a=1,)], o) == [(a=-3,)]
end

@testitem "tmp" begin
#     data = [
#         (a=1, bs=[10, 11, 12]),
#         (a=2, bs=[20, 21]),
#     ]
#     o = @optic _ |> Elements() ...
#     getall(data, o, o, 5) == [(a=1, b=10), (a=1, b=11), ...]
#     modify((a, b) -> 100a + b, data, o) == [
#         (a=1, bs=[110, 111, 112]),
#         (a=2, bs=[220, 221]),
#     ]

#     o = @optic _ |> Elements() |> If(r -> any(>(15), r.bs)) |> _.a
#     @test modify(a -> a * 2, data, o) == [
#         (a=1, bs=[10, 11, 12]),
#         (a=4, bs=[20, 21]),
#     ]
#     o = @optic _ |> Elements() |> If(r -> !isempty(getall(r, @optic(_.bs |> Elements() |> If(>(15)))))) |> _.a
#     @test modify(a -> a * 2, data, o) == [
#         (a=1, bs=[10, 11, 12]),
#         (a=4, bs=[20, 21]),
#     ]

#     o = # bs >= 12
#     @test modify((a, bs) -> a + length(bs), data, o) == [
#         (a=2, bs=[10, 11, 12]),
#         (a=4, bs=[20, 21]),
#     ]

#     @test delete(data, @optic _ |> Elements() |> _.bs |> Elements() |> If(isodd))
#     @test delete(data, @optic _ |> Elements() |> If(r -> !isempty(getall(r, @optic _.bs |> Elements() |> If(>(15))))))
#     @test modify(b -> isodd(b) ? nothing : b, data, @optic _ |> Elements() |> _.bs |> Withered())
#     @test modify(b -> isodd(b) ? nothing : b, data, @optic _ |> Withered() |> _.bs |> Elements())
#     @test modify(b -> isodd(b) ? nothing : b, data, @optic _ |> Withered() |> _.bs |> Withered())
end

@testitem "replace" begin
    nt = (a=1, b=:x)
    AccessorsExtra.@allinferred _replace begin
        @test AccessorsExtra._replace(nt, @optic(_.a) => @optic(_.c)) === (c=1, b=:x)
        @test AccessorsExtra._replace(nt, (@optic(_.a) => @optic(_.c)) ∘ identity) === (c=1, b=:x)
    end
    @test @replace(nt.c = nt.a) === (c=1, b=:x)
    @test @replace(nt.c = _.a) === (c=1, b=:x)
    @test @replace(_.c = nt.a) === (c=1, b=:x)
    @test @replace(nt |> (_.c = _.a)) === (c=1, b=:x)

    @test_throws Exception eval(:(@replace(nt_1.c = nt_2.a)))
    @test_throws Exception eval(:(@replace(_.c = _.a)))
end

@testitem "assemble" begin
    ==ₜ(_, _) = false
    ==ₜ(x::T, y::T) where T = x == y

    AccessorsExtra.@allinferred assemble begin
        @test assemble(Complex, @optic(_.re) => 1, @optic(_.im) => 2)::Complex{Int} === 1 + 2im
        @test assemble(Complex{Int}, @optic(_.re) => 1, @optic(_.im) => 2)::Complex{Int} === 1 + 2im
        @test assemble(ComplexF32, @optic(_.re) => 1, @optic(_.im) => 2)::ComplexF32 == 1 + 2im
        @test assemble(Complex, @optic(_.re) => 1., @optic(_.im) => 2)::ComplexF64 === 1. + 2im
        @test assemble(Complex, abs => 1., angle => π/2)::ComplexF64 ≈ 1im
        @test assemble(ComplexF32, abs => 1., angle => π/2)::ComplexF32 ≈ 1im
        @test_throws InexactError assemble(Complex{Int}, abs => 1., angle => π/2)

        @test assemble(Tuple, only => 1) === (1,)
        @test assemble(Tuple{Int}, only => 1) === (1,)
        @test assemble(Tuple{Float64}, only => 1) === (1.0,)
        @test_throws Exception assemble(Tuple{String}, only => 1)
        @test_throws Exception assemble(Tuple{Int, Int}, only => 1)

        @test assemble(Vector, only => 1) ==ₜ [1]
        @test assemble(Vector{Int}, only => 1) ==ₜ [1]
        @test assemble(Vector{Float64}, only => 1) ==ₜ [1.0]
        @test_throws Exception assemble(Vector{String}, only => 1)

        @test assemble(Set, only => 1) ==ₜ Set((1,))
        @test assemble(Set{Int}, only => 1) ==ₜ Set((1,))
        @test assemble(Set{Float64}, only => 1) ==ₜ Set((1.0,))
        @test_throws Exception assemble(Set{String}, only => 1,)

        @test assemble(NamedTuple{(:a,)}, only => 1) === (a=1,)
        @test assemble(NamedTuple, @optic(_.a) => 1) === (a=1,)
        @test assemble(NamedTuple, @optic(_.a) => 1, @optic(_.b) => "") === (a=1, b="")
    end

    @test @assemble(Complex, _.re = 1, _.im = 2)::Complex{Int} === 1 + 2im
    @test (@assemble Complex{Int}  _.re = 1 _.im = 2)::Complex{Int} === 1 + 2im
    res = @assemble Complex begin
        _.re = 1
        _.im = 2
    end
    @test res::Complex{Int} === 1 + 2im
    res = @assemble Complex{Int} begin
        _.re = 1
        _.im = 2
    end
    @test res::Complex{Int} === 1 + 2im
    res = @assemble NamedTuple begin
        _.a = @assemble Complex  abs(_) = 1 angle(_) = π
        _.b = @assemble Vector  only(_) = 10
        _.c = 123
    end
    @test res == (a=-1, b=[10], c=123)
    res = @assemble NamedTuple begin
        _.a = assemble(Complex, @optic(_.re) => -1, @optic(_.im) => 0)
        _.b = assemble(Vector, only => 10)
        _.c = 123
    end
    @test res == (a=-1, b=[10], c=123)
end

@testitem "structarrays" begin
    using StructArrays

    s = StructArray(a=[1, 2, 3])
    @test setproperties(s, a=10:12)::StructArray == StructArray(a=10:12)
    @test_throws ArgumentError setproperties(s, b=10:12)
end

@testitem "getfield" begin
    t = (x=1, y=2)
    @test set(t, @optic(getfield(_, :x)), :hello) === (x=:hello, y=2)
    @test_throws Exception set(t, @optic(getfield(_, :z)), 3)
end

@testitem "view" begin
    A = [1, 2]
    @test set(A, @optic(view(_, 2)[]), 10) === A == [1, 10]
    @test modify(-, A, @optic(view(_, 2)[] + 1)) === A == [1, -12]

    Accessors.test_getset_laws(@optic(view(_, 2)[]), [1, 2], 5, -1)
    Accessors.test_getset_laws(@optic(view(_, 1:2)), [1, 2], 1:2, 5:6)

    A = [1, 2, (a=3, b=4)]
    @test set(A, @optic(view(_, 1:2)), [-2, -3]) === A == [-2, -3, (a=3, b=4)]
    @test @modify(x -> 2x, A |> view(_, 1:2)) === A == [-4, -6, (a=3, b=4)]
    @test @modify(x -> x + 1, A |> view(_, 1:2) |> Elements()) === A == [-3, -5, (a=3, b=4)]
end

@testitem "inverses" begin
    using InverseFunctions
    using Distributions
    using Unitful

    InverseFunctions.test_inverse(Base.Fix1(getindex, [4, 5, 6]), 2)
    InverseFunctions.test_inverse(Base.Fix1(getindex, Dict(2 => 123, 3 => 456)), 2)

    d = Normal(2, 5)
    InverseFunctions.test_inverse(@optic(cdf(d, _)), 2)
    InverseFunctions.test_inverse(@optic(quantile(d, _)), 0.1)

    InverseFunctions.test_inverse(@optic(ustrip(u"m", _)), 2u"m")
    InverseFunctions.test_inverse(@optic(ustrip(u"m", _)), 2u"mm")

    InverseFunctions.test_inverse(Accessors.decompose, sin ∘ tan ∘ cos; compare= ==)
    InverseFunctions.test_inverse(Accessors.deopcompose, sin ∘ tan ∘ cos; compare= ==)
end

@testitem "collections" begin
    o = @optic map(-, _)  # invertible
    Accessors.test_getset_laws(o, [1, 2], [3, 4], [5, 6])
    o = @optic map(only, _)  # non-invertible
    Accessors.test_getset_laws(o, [(1,), (2,)], [(3,), (4,)], [(5,), (6,)])
    o = @optic filter(>(0), _)
    Accessors.test_getset_laws(o, [1, -2, 3, -4, 5, -6], [1, 2, 3], [1, 3, 5])
    @test modify([1, -2, 3, -4, 5, -6], o) do x
        x .+ sum(x)
    end == [10, -2, 12, -4, 14, -6]
end

@testitem "keys, values, pairs" begin
    using Dictionaries

    # ds = Dict(:a => 1:10,:b => 2:11)
    # delete(If) not possible? need Filtered(cond) == If(cond) ∘ Elements()
    # @test @delete ds |> values(_)[∗] |> If(x -> any(>=(5), x))
    # @test @delete ds |> values(_)[∗][∗] |> If(>=(5))

    AccessorsExtra.@allinferred modify begin
        @test modify(cumsum, [5, 1, 4, 2, 3], sort) == [15, 1, 10, 3, 6]

        T = (4, 5, 6)
        @test (8, 10, 12) === modify(x -> 2x, T, @optic values(_)[∗])
        @test (5, 7, 9) === modify(((i, x),) -> i => i + x, T, @optic pairs(_)[∗])
        @test_throws AssertionError @modify(((i, x),) -> (i+1) => i + x, T |> @optic pairs(_)[∗])
        T = (a=4, b=5, c=6)
        @test (a=8, b=10, c=12) === modify(x -> 2x, T, @optic values(_)[∗])
        @test_broken (aa=4, bb=5, cc=6) === modify(x -> Symbol(x, x), (a=4, b=5, c=6), @optic keys(_)[∗])  # doesn't infer, but result correct
        @test (a=(:a, 8), b=(:b, 10), c=(:c, 12)) === modify(((i, x),) -> i => (i, 2x), T, @optic pairs(_)[∗])
        A = [4, 5, 6]
        @test [8, 10, 12] == modify(x -> 2x, A, @optic values(_)[∗])
        @test [5, 7, 9] == modify(((i, x),) -> i => i + x, A, @optic pairs(_)[∗])
        D = Dict(4 => 5, 6 => 7)
        @test Dict(4 => 6, 6 => 8) == modify(x -> x+1, D, @optic values(_)[∗])
        @test Dict(5 => 5, 7 => 7) == modify(x -> x+1, D, @optic keys(_)[∗])
        @test Dict(8 => 9, 12 => 13) == modify(((i, x),) -> 2i => i + x, D, @optic pairs(_)[∗])
        D = dictionary([4 => 5, 6 => 7])
        @test dictionary([4 => 6, 6 => 8]) == modify(x -> x+1, D, @optic values(_)[∗])
        @test dictionary([5 => 5, 7 => 7]) == modify(x -> x+1, D, @optic keys(_)[∗])
        D = ArrayDictionary([4, 6], [5, 7])
        @test dictionary([4 => 6, 6 => 8]) == modify(x -> x+1, D, @optic values(_)[∗])
        @test dictionary([5 => 5, 7 => 7]) == modify(x -> x+1, D, @optic keys(_)[∗])
    end
    @test (aa=4, bb=5, cc=6) === modify(x -> Symbol(x, x), (a=4, b=5, c=6), @optic keys(_)[∗])
end

@testitem "skycoords" begin
    using SkyCoords
    using SkyCoords: lat, lon

    for T in [ICRSCoords, FK5Coords{2000}, GalCoords]
        c = T(0.5, -1)
        @test @set(lat(c) = 1.2) == T(0.5, 1.2)
        @test lat(@set(lat(c) = 1.2)) == 1.2
        @test @set(lon(c) = 2.3) == T(2.3, -1)
        @test lon(@set(lon(c) = 2.3)) == 2.3
    end
    c = ICRSCoords(0.5, -1)
    c1 = @set(c |> convert(GalCoords, _) |> lon = 0)::ICRSCoords
    @test c1.ra ≈ 5.884005859354123
    @test c1.dec ≈ -0.69919820078915
end

@testitem "_" begin
    import CompatHelperLocal as CHL
    CHL.@check()

    using Aqua
    Aqua.test_all(AccessorsExtra, piracy=false, ambiguities=false)
end
