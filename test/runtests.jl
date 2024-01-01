using TestItems
using TestItemRunner
@run_package_tests


@testitem "setindex" begin
    using Dictionaries

    dct = dictionary([:a => 1, :b => 2])
    DT = Dictionary{Symbol,Int}
    @test @set(dct[:a] = 10)::DT == dictionary([:a => 10, :b => 2])
    @test @set(dct[:a] = 10.)::Dictionary{Symbol,Float64} == dictionary([:a => 10, :b => 2])
    @test @delete(dct[:a])::DT == dictionary([:b => 2])
    @test @insert(dct[:c] = 5)::DT == dictionary([:a => 1, :b => 2, :c => 5])
end

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

    obj = (a=1, bs=((c=2, d=3), (c=4, d=5)))
    o = concat(a=@optic(_.a), c=@optic(first(_.bs) |> _.c))
    AccessorsExtra.@allinferred getall modify delete if VERSION >= v"1.10-"; :setall end begin
        @test getall(obj, o) === (a=1, c=2)
        @test setall(obj, o, (a="10", c="11")) === (a="10", bs=((c="11", d=3), (c=4, d=5)))
        @test setall(obj, o, (c="11", a="10")) === (a="10", bs=((c="11", d=3), (c=4, d=5)))
        @test modify(float, obj, o) === (a=1.0, bs=((c=2.0, d=3), (c=4, d=5)))
    end
    # doesn't infer due to "bounded recursion
    @test delete(obj, o) === (bs=((d=3,), (c=4, d=5)),)
    

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

    AccessorsExtra.@allinferred o set modify begin
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

    o = @optic₊ (_.a.b + 1, -_.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (2, -3)
    @test set(m, o, (4, 5)) == (a=(b=3, c=2), c=-5)
    @test modify(xs -> xs ./ sum(xs), m, o) == (a=(b=-3.0, c=2), c=-3.0)
    end
    
    o = @optic₊ SVector(_.a.b, _.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == SVector(1, 3)
    @test set(m, o, SVector(4, 5)) == (a=(b=4, c=2), c=5)
    @test modify(xs -> 2*xs, m, o) == (a=(b=2, c=2), c=6)

    o = @optic₊ Pair(_.a.b, _.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (1 => 3)
    @test set(m, o, 4 => 5) == (a=(b=4, c=2), c=5)

    o = @optic₊ _.a.b => _.c
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (1 => 3)
    @test set(m, o, 4 => 5) == (a=(b=4, c=2), c=5)
    
    o = @optic₊ [_.a.b, _.c]
    m = (a=(b=1, c=2), c=3)
    @test o(m) == [1, 3]
    @test set(m, o, [4, 5]) == (a=(b=4, c=2), c=5)
    @test modify(xs -> 2*xs, m, o) == (a=(b=2, c=2), c=6)
    
    # o = @optic₊ Dict("x" => _.a.b, "y" => _.c)
    # m = (a=(b=1, c=2), c=3)
    # @test o(m) == Dict("x" => 1, "y" => 3)
    # @test set(m, o, Dict("x" => 4, "y" => 5)) == (a=(b=4, c=2), c=5)
    # @test set(m, o, Dict("y" => 5, "x" => 4)) == (a=(b=4, c=2), c=5)

    o = @optic₊ (x=(u=_.a.b, v=_.c), y=_.a.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (x=(u=1, v=3), y=2)
    @test set(m, o, (x=(u=5, v=6), y=7)) == (a=(b=5, c=7), c=6)

    o = @optic₊ (x=[_.a.b, _.c], y=_.a.c)
    m = (a=(b=1, c=2), c=3)
    @test o(m) == (x=[1, 3], y=2)
    @test set(m, o, (x=[5, 6], y=7)) == (a=(b=5, c=7), c=6)
end

@testitem "shorter forms" begin
    o = @optic(_.a[∗].b[∗ₚ].c[2])
    @test o === @optic(_.a |> Elements() |> _.b |> Properties() |> _.c[2])
    @test sprint(show, o) == "(@optic _.a[∗].b[∗ₚ].c[2])"
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
    AccessorsExtra.@allinferred modify set begin
    # @test set(1, something, 2) == 2
    # @test set(Some(1), something, 2) == Some(2)

    o = osomething(@optic(_.a), @optic(_.b))
    # o = @osomething(_.a, _.b)
    @test o((a=1, b=2)) == 1
    @test o((c=1, b=2)) == 2
    @test_throws "no optic" o((c=1,))
    @test set((a=1, b=2), o, 10) == (a=10, b=2)
    @test set((c=1, b=2), o, 10) == (c=1, b=10)
    @test_throws "no optic" set((c=1,), o, 10)

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

    for o in (maybe(@optic _.a) ⨟ maybe(@optic(_.b)), maybe(@optic _.a.b))
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

    for o in [maybe(@optic first(_).a), maybe(@optic last(_).a)]
        for obj in ([(a=1,)], [(b=1,)], [(a=1,), (b=2,)], [(b=1,), (a=2,)],)
            Accessors.test_getset_laws(o, obj, 10, 20)
        end
        @test o([(a=1,)]) === 1
        @test o([]) === nothing
        @test o([(b=1,)]) === nothing
        @test modify(x -> x+1, [], o) == []
    end
    o = maybe(@optic only(_).a)
    @test o([(a=1,)]) == 1
    @test o([(a=1,), (a=2,)]) === nothing

    o = maybe(@optic last(_.a, 3))
    @test o((a=[1, 2, 3, 4, 5],)) == [3, 4, 5]
    @test o((a=[4, 5],)) == [4, 5]
    @test o((a=[],)) == []
    @test o((a=nothing,)) === nothing
    @test o(()) === nothing
    @test o(nothing) === nothing

    o = maybe(@optic parse(Int, _))
    @test o("1") == 1
    @test o("a") === nothing
    @test o(nothing) === nothing
    @test modify(x -> x+1, "1", o) == "2"
    @test modify(x -> x+1, "a", o) == "a"
    @test set("1", o, 2) == "2"
    @test_broken set("a", o, 2) == "2"

    # specify default value - semantic not totally clear...
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
end

@testitem "recursive" begin
    using StaticArrays

    AccessorsExtra.@allinferred modify getall setall begin
    or = RecursiveOfType(Number, ∗, recurse=Union{Tuple,AbstractVector,NamedTuple})
    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx")))
    @test getall(m, or) == (1, 1, 3)
    @test modify(x->x+10, m, or) == (a=11, bs=((c=11, d="2"), (c=13, d="xxx")))
    @test setall(m, or, (10, 20, 30)) == (a=10, bs=((c=20, d="2"), (c=30, d="xxx")))

    m = (a=1, bs=[(c=1, d="2"), (c=3, d="xxx")])
    @test getall(m, or) == [1, 1, 3]
    @test modify(x->x+10, m, or) == (a=11, bs=[(c=11, d="2"), (c=13, d="xxx")])
    @test_throws Exception setall(m, or, [10, 20, 30])  # setall not supported with dynamic length vectors
    @test getall(m, or) == getall(m, or)

    m = (a=1, bs=SVector((c=1, d="2"), (c=3, d="xxx")))
    @test getall(m, or) == SVector(1, 1, 3)
    @test modify(x->x+10, m, or) == (a=11, bs=[(c=11, d="2"), (c=13, d="xxx")])
    @test setall(m, or, (10, 20, 30)) == (a=10, bs=SVector((c=20, d="2"), (c=30, d="xxx")))
    @test getall(m, or) == getall(m, or)

    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx")))
    or = RecursiveOfType(NamedTuple)
    @test getall(m, or) == ((c = 1, d = "2"), (c = 3, d = "xxx"), m)
    @test modify(Dict ∘ pairs, m, or) == Dict(:a => 1, :bs => (Dict(:d => "2", :c => 1), Dict(:d => "xxx", :c => 3)))
    @test modify(Dict ∘ pairs, m, or) == modify(Dict ∘ pairs, m, or)

    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx", e=((;),))))
    @test getall(m, or) == ((c = 1, d = "2"), (;), (c = 3, d = "xxx", e = ((;),)), (a = 1, bs = ((c = 1, d = "2"), (c = 3, d = "xxx", e = ((;),)))))

    m = (a=1, b=2+3im)
    or = RecursiveOfType(Real)
    @test getall(m, or) == (1, 2, 3)
    @test modify(x->x+10, m, or) == (a=11, b=12+13im)
    @test getall(m, or) == getall(m, or)
    @test setall(m, or, (10, 20, 30)) == (a=10, b=20+30im)
    end
end

@testitem "context" begin
    AccessorsExtra.@allinferred modify begin
    obj = ((a='a',), (a='b',), (a='c',))
    o = keyed(Elements()) ⨟ @optic(_.a)
    @test modify(((i, v),) -> i => v, obj, o) == ((a=1=>'a',), (a=2=>'b',), (a=3=>'c',))
    o = keyed(Elements()) ⨟ @optic(_.a) ⨟ @optic(convert(Int, _) + 1)
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((1, 98), (2, 99), (3, 100))
    @test modify(((i, v),) -> i + v, obj, o) == ((a='b',), (a='d',), (a='f',))
    o = Elements() ⨟ keyed(Elements())
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((:a, 'a'), (:a, 'b'), (:a, 'c'))
    @test modify(((i, v),) -> v, obj, o) == obj
    end

    o = @optic(_.b) ⨟ keyed(Elements()) ⨟ @optic(_.a)
    @test modify(((i, v),) -> i => v, (a=1, b=((a='a',), (a='b',), (a='c',))), o) == (a=1, b=((a=1=>'a',), (a=2=>'b',), (a=3=>'c',)))
    @test modify(((i, v),) -> i => v, (a=1, b=[(a='a',), (a='b',), (a='c',)]), o) == (a=1, b=[(a=1=>'a',), (a=2=>'b',), (a=3=>'c',)])
    @test modify(
        wix -> wix.ctx => wix.v,
        (a=1, b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        keyed(@optic(_.a)) ++ keyed(@optic(_.b)) ⨟ @optic(_[∗].a)
    ) == (a=:a=>1, b=(x=(a=:b=>'a',), y=(a=:b=>'b',), z=(a=:b=>'c',)))
    @test modify(
        wix -> wix.ctx => wix.v,
        (a=[(a=1,)], b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        (keyed(@optic(_.a)) ++ keyed(@optic(_.b))) ⨟ @optic(_[∗].a)ᵢ
    ) == (a=[(a=:a=>1,)], b=(x=(a=:b=>'a',), y=(a=:b=>'b',), z=(a=:b=>'c',)))
    @test modify(
        wix -> wix.ctx => wix.v,
        (a=1, b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        @optic(_.b) ⨟ keyed(Elements()) ⨟ Elements()
    ) == (a=1, b=(x=(a=:x=>'a',), y=(a=:y=>'b',), z=(a=:z=>'c',)))

    AccessorsExtra.@allinferred modify begin
    @test modify(
        wix -> wix.v / wix.ctx.total,
        ((x=5, total=10,), (x=2, total=20,), (x=3, total=8,)),
        Elements() ⨟ selfcontext() ⨟ @optic(_.x)
    ) == ((x=0.5, total=10,), (x=0.1, total=20,), (x=0.375, total=8,))
    @test modify(
        wix -> wix.v / wix.ctx,
        ((x=5, total=10,), (x=2, total=20,), (x=3, total=8,)),
        Elements() ⨟ selfcontext(r -> r.total) ⨟ @optic(_.x)
    ) == ((x=0.5, total=10,), (x=0.1, total=20,), (x=0.375, total=8,))

    str = "abc def 5 x y z 123"
    o = @optic(eachmatch(r"\w+", _)) ⨟ enumerated(Elements())
    @test map(wix -> "$(wix.v.match)_$(wix.ctx)", getall(str, o)) == ["abc_1", "def_2", "5_3", "x_4", "y_5", "z_6", "123_7"]
    @test modify(
        wix -> "$(wix.v.match)_$(wix.ctx)",
        str,
        o
    ) == "abc_1 def_2 5_3 x_4 y_5 z_6 123_7"
    @test modify(
        wix -> wix.v + wix.ctx,
        str,
        @optic(eachmatch(r"\d+", _)) ⨟ enumerated(Elements()) ⨟ @optic(parse(Int, _.match))
    ) == "abc def 6 x y z 125"
    @test modify(
        wix -> "$(wix.ctx):$(wix.v)",
        "2022-03-15",
        @optic(match(r"(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})", _)) ⨟ keyed(Elements())
    ) == "y:2022-m:03-d:15"
    end

    data = [
        (a=1, bs=[10, 11, 12]),
        (a=2, bs=[20, 21]),
    ]
    o = @optic _[∗] |> selfcontext() |> _.bs[∗]
    @test map(x -> (;x.ctx.a, b=x.v), getall(data, o)) == [(a = 1, b = 10), (a = 1, b = 11), (a = 1, b = 12), (a = 2, b = 20), (a = 2, b = 21)]
    @test modify(x -> 100*x.ctx.a + x.v, data, o) == [
        (a=1, bs=[110, 111, 112]),
        (a=2, bs=[220, 221]),
    ]
end

@testitem "PartsOf" begin
    x = (a=((b=1,), (b=2,), (b=3,)), c=4)
    @test (@optic _.a[∗].b |> PartsOf())(x) == (1, 2, 3)
    @test (@optic _.a[∗].b |> PartsOf() |> length)(x) == 3
    o = @optic _.a[∗].b
    @test getall(x, o) == (o ⨟ PartsOf())(x) == (1, 2, 3)
    o = (@optic(_.a[∗].b) ++ @optic(_.c)) ⨟ PartsOf()
    @test modify(reverse, x, o) == (a=((b=4,), (b=3,), (b=2,)), c=1)
    o = (@optic(_.a[∗].b) ++ @optic(_.c)) ⨟ @optic(_ |> PartsOf() |> _[2])
    @test modify(x -> x*10, x, o) == (a=((b=1,), (b=20,), (b=3,)), c=4)
    o = (@optic(_.a[∗].b) ++ @optic(_.c)) ⨟ @optic(_ |> PartsOf()) ⨟ @optics _[1] _[2]
    @test modify(x -> x*10, x, o) == (a=((b=10,), (b=20,), (b=3,)), c=4)
    @test modify(
        xs -> round.(Int, xs ./ sum(xs) .* 100),
        "Counts: 10, 15, and 25!",
        @optic(eachmatch(r"\d+", _)[∗] |> parse(Int, _.match) |> PartsOf())
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
    o = logged(@optics _[∗].a + 1 _[1].a)
    @test getall([(a=1,)], o) == [2, 1]
    o = logged(@optic₊ (_[1].a + 1, _[1].a))
    @test o([(a=1,)]) == (2, 1)
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

@testitem "construct" begin
    ==ₜ(_, _) = false
    ==ₜ(x::T, y::T) where T = x == y

    @testset "basic usage" begin
        AccessorsExtra.@allinferred construct begin
            @test construct(Complex, @optic(_.re) => 1, @optic(_.im) => 2)::Complex{Int} === 1 + 2im
            @test construct(ComplexF32, @optic(_.re) => 1, @optic(_.im) => 2)::ComplexF32 === 1f0 + 2f0im
            @test_throws InexactError construct(Complex{Int}, abs => 1., angle => π/2)

            @test construct(Tuple, only => 1) === (1,)
            @test construct(Tuple{Float64}, only => 1) === (1.0,)
            @test_throws Exception construct(Tuple{String}, only => 1)
            @test_throws Exception construct(Tuple{Int, Int}, only => 1)

            @test construct(Vector, only => 1) ==ₜ [1]
            @test construct(Vector{Float64}, only => 1) ==ₜ [1.0]
            @test_throws Exception construct(Vector{String}, only => 1)

            @test construct(Set, only => 1) ==ₜ Set((1,))
            @test construct(Set{Float64}, only => 1) ==ₜ Set((1.0,))
            @test_throws Exception construct(Set{String}, only => 1,)

            @test construct(NamedTuple, @optic(_.a) => 1, @optic(_.b) => "") === (a=1, b="")
        end
    end

    @testset "laws" begin
        using AccessorsExtra: test_construct_laws
        test_construct_laws(Complex, @optic(_.re) => 1, @optic(_.im) => 2)
        test_construct_laws(Complex{Int}, @optic(_.re) => 1, @optic(_.im) => 2)
        test_construct_laws(ComplexF32, @optic(_.re) => 1, @optic(_.im) => 2)
        test_construct_laws(Complex, @optic(_.re) => 1., @optic(_.im) => 2)
        test_construct_laws(Complex, abs => 1., angle => π/2)
        test_construct_laws(ComplexF32, abs => 1., angle => π/2; cmp=(≈))

        test_construct_laws(Tuple, only => 1)
        test_construct_laws(Tuple{Int}, only => 1)
        test_construct_laws(Tuple{Float64}, only => 1)

        test_construct_laws(Vector, only => 1)
        test_construct_laws(Vector{Int}, only => 1)
        test_construct_laws(Vector{Float64}, only => 1)

        test_construct_laws(Set, only => 1)
        test_construct_laws(Set{Int}, only => 1)
        test_construct_laws(Set{Float64}, only => 1)

        test_construct_laws(NamedTuple{(:a,)}, only => 1)
        test_construct_laws(NamedTuple, @optic(_.a) => 1)
        test_construct_laws(NamedTuple, @optic(_.a) => 1, @optic(_.b) => "")
    end

    @testset "macro" begin
        @test @construct(Complex, _.re = 1, _.im = 2)::Complex{Int} === 1 + 2im
        @test (@construct Complex{Int}  _.re = 1 _.im = 2)::Complex{Int} === 1 + 2im
        res = @construct Complex begin
            _.re = 1
            _.im = 2
        end
        @test res::Complex{Int} === 1 + 2im
        res = @construct Complex{Int} begin
            _.re = 1
            _.im = 2
        end
        @test res::Complex{Int} === 1 + 2im
        res = @construct NamedTuple begin
            _.a = @construct Complex  abs(_) = 1 angle(_) = π
            _.b = @construct Vector  only(_) = 10
            _.c = 123
        end
        @test res == (a=-1, b=[10], c=123)
        res = @construct NamedTuple begin
            _.a = construct(Complex, @optic(_.re) => -1, @optic(_.im) => 0)
            _.b = construct(Vector, only => 10)
            _.c = 123
        end
        @test res == (a=-1, b=[10], c=123)
    end
end

@testitem "structarrays" begin
    using StructArrays

    s = StructArray(a=[1, 2, 3])
    @test setproperties(s, a=10:12)::StructArray == StructArray(a=10:12)
    @test_throws ArgumentError setproperties(s, b=10:12)
    @test @modify(c -> c .+ 1, s |> Properties()) == StructArray(a=[2, 3, 4])

    s = StructArray(([1, 2, 3],))
    @test setproperties(s, (10:12,))::StructArray == StructArray((10:12,))
    @test @modify(c -> c .+ 1, s |> Properties()) == StructArray(([2, 3, 4],))
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
    using Unitful

    InverseFunctions.test_inverse(Base.Fix1(getindex, [4, 5, 6]), 2)
    InverseFunctions.test_inverse(Base.Fix1(getindex, Dict(2 => 123, 3 => 456)), 2)

    InverseFunctions.test_inverse(@optic(ustrip(u"m", _)), 2u"m")
    InverseFunctions.test_inverse(@optic(ustrip(u"m", _)), 2u"mm")

    InverseFunctions.test_inverse(Accessors.decompose, sin ∘ tan ∘ cos; compare= ==)
    InverseFunctions.test_inverse(Accessors.deopcompose, sin ∘ tan ∘ cos; compare= ==)
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
    using Dictionaries

    # ds = Dict(:a => 1:10,:b => 2:11)
    # delete(If) not possible? need Filtered(cond) == If(cond) ∘ Elements()
    # @test @delete ds |> values(_)[∗] |> If(x -> any(>=(5), x))
    # @test @delete ds |> values(_)[∗][∗] |> If(>=(5))

    AccessorsExtra.@allinferred modify begin
        T = (4, 5, 6)
        @test (8, 10, 12) === modify(x -> 2x, T, @optic values(_)[∗])
        @test (5, 7, 9) === modify(((i, x),) -> i => i + x, T, @optic pairs(_)[∗])
        @test_throws AssertionError @modify(((i, x),) -> (i+1) => i + x, T |> @optic pairs(_)[∗])
        T = (a=4, b=5, c=6)
        @test (a=8, b=10, c=12) === modify(x -> 2x, T, @optic values(_)[∗])
        @test (aa=4, bb=5, cc=6) === modify(x -> Symbol(x, x), (a=4, b=5, c=6), @optic keys(_)[∗])  broken=VERSION < v"1.10-"
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
        @test dictionary([8 => 9, 12 => 13]) == modify(((i, x),) -> 2i => i + x, D, @optic pairs(_)[∗])
        D = ArrayDictionary([4, 6], [5, 7])
        @test dictionary([4 => 6, 6 => 8]) == modify(x -> x+1, D, @optic values(_)[∗])
        @test dictionary([5 => 5, 7 => 7]) == modify(x -> x+1, D, @optic keys(_)[∗])
    end
    @test (aa=4, bb=5, cc=6) === modify(x -> Symbol(x, x), (a=4, b=5, c=6), @optic keys(_)[∗])
end

@testitem "Optimization" begin
    using IntervalSets
    using StructArrays
    using StaticArrays
    using Optimization
    using OptimizationOptimJL, OptimizationMetaheuristics

    @testset "reconstruct" begin
        of = OptimizationFunction(sin, Optimization.AutoForwardDiff())
        @test constructorof(typeof(of))(Accessors.getfields(of)...) === of
    end

    
    struct ExpModel{A,B}
        scale::A
        shift::B
    end
    
    struct SumModel{T <: Tuple}
        comps::T
    end
    
    (m::ExpModel)(x) = m.scale * exp(-(x - m.shift)^2)
    (m::SumModel)(x) = sum(c -> c(x), m.comps)

    loss(m, data) = sum(r -> abs2(r.y - m(r.x)), data)

    truemod = SumModel((
        ExpModel(2, 5),
        ExpModel(0.5, 2),
        ExpModel(0.5, 8),
    ))

    data = let x = 0:0.2:10
        StructArray(; x, y=truemod.(x) .+ range(-0.01, 0.01, length=length(x)))
    end

    mod0 = SumModel((
        ExpModel(1, 1),
        ExpModel(1, 2),
        ExpModel(1, 3),
    ))
    vars = OptArgs(
        @optic(_.comps[∗].shift) => 0..10.,
        @optic(_.comps[∗].scale) => 0.3..10.,
    )
    prob = OptProblemSpec(Base.Fix2(loss, data), mod0, vars)
    sol = solve(prob, ECA(), maxiters=300)
    @test sol.u isa Vector{Float64}
    @test sol.uobj isa SumModel
    @test getall(sol.uobj, @optic _.comps[∗].shift) |> collect |> sort ≈ [2, 5, 8]  rtol=1e-2

    @testset "no autodiff" begin
    @testset "OptProblemSpec(utype=$(prob.utype))" for prob in (
        OptProblemSpec(Base.Fix2(loss, data), mod0, vars),
        OptProblemSpec(Base.Fix2(loss, data), Vector, mod0, vars),
        OptProblemSpec(Base.Fix2(loss, data), Vector{Float64}, mod0, vars),
        OptProblemSpec(Base.Fix2(loss, data), SVector, mod0, vars),
        OptProblemSpec(Base.Fix2(loss, data), SVector{<:Any, Float64}, mod0, vars),
        OptProblemSpec(Base.Fix2(loss, data), MVector, mod0, vars),
        OptProblemSpec(Base.Fix2(loss, data), MVector{<:Any, Float64}, mod0, vars),
        OptProblemSpec(Base.Fix2(OptimizationFunction{false}(loss), data), mod0, vars),
        OptProblemSpec(Base.Fix2(OptimizationFunction{false}(loss), data), Vector, mod0, vars),
        OptProblemSpec(Base.Fix2(OptimizationFunction{false}(loss), data), Vector{Float64}, mod0, vars),
        OptProblemSpec(Base.Fix2(OptimizationFunction{false}(loss), data), SVector, mod0, vars),
        OptProblemSpec(Base.Fix2(OptimizationFunction{false}(loss), data), SVector{<:Any, Float64}, mod0, vars),
        OptProblemSpec(Base.Fix2(OptimizationFunction{false}(loss), data), MVector, mod0, vars),
        OptProblemSpec(Base.Fix2(OptimizationFunction{false}(loss), data), MVector{<:Any, Float64}, mod0, vars),
    )
        sol = solve(prob, ECA(), maxiters=300)
        @test sol.u isa Vector{Float64}
        @test sol.uobj isa SumModel
    end
    end

    cons = OptCons(
        ((x, _) -> sum(c -> c.shift, x.comps) / length(x.comps)) => 0.5..4,
    )
    @testset "autodiff" begin
    @testset "OptProblemSpec(utype=$(prob.utype))" for prob in (
        OptProblemSpec(Base.Fix2(OptimizationFunction(loss, Optimization.AutoForwardDiff()), data), Vector{Float64}, mod0, vars, cons),
    )
        sol = solve(prob, Optim.IPNewton(), maxiters=300)
        @test sol.u isa Vector{Float64}
        @test sol.uobj isa SumModel
        for (f, int) in cons.specs
            @test f(sol.uobj, data) ∈ int
        end
    end
    end
end

@testitem "_" begin
    import CompatHelperLocal as CHL
    CHL.@check()

    using Aqua
    Aqua.test_all(AccessorsExtra, piracy=false, ambiguities=false, project_toml_formatting=false)
end
