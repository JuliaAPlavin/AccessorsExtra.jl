using TestItems
using TestItemRunner
@run_package_tests


@testitem "Dictionaries" begin
    using Dictionaries
    using UnionCollections
    const UnionDictionary = Base.get_extension(UnionCollections, :DictionariesExt).UnionDictionary

    dct = dictionary([:a => 1, :b => 2])
    DT = Dictionary{Symbol,Float64}
    @test @set(dct[:a] = 10)::typeof(dct) == dictionary([:a => 10, :b => 2])
    @test @set(dct[:a] = 10.)::DT == dictionary([:a => 10, :b => 2])
    @test @delete(dct[:a])::typeof(dct) == dictionary([:b => 2])
    @test @insert(dct[:c] = 5.)::DT == dictionary([:a => 1, :b => 2, :c => 5])

    dct = ArrayDictionary(dct)
    DT = ArrayDictionary{Symbol,Float64}
    @test @set(dct[:a] = 10)::typeof(dct) == dictionary([:a => 10, :b => 2])
    @test @set(dct[:a] = 10.)::DT == dictionary([:a => 10, :b => 2])
    @test @delete(dct[:a])::typeof(dct) == dictionary([:b => 2])
    @test @insert(dct[:c] = 5.)::DT == dictionary([:a => 1, :b => 2, :c => 5])

    dct = unioncollection(dct)
    DT = UnionDictionary{Symbol,Union{Int,Float64}}
    @test @set(dct[:a] = 10)::UnionDictionary{Symbol,Int} == dictionary([:a => 10, :b => 2])
    @test @set(dct[:a] = 10.)::DT == dictionary([:a => 10, :b => 2])
    @test @delete(dct[:a])::UnionDictionary{Symbol,Int} == dictionary([:b => 2])
    @test @insert(dct[:c] = 5.)::DT == dictionary([:a => 1, :b => 2, :c => 5])
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

@testitem "propertyfunction" begin
    using AccessorsExtra: needed_properties
    o = @o _.a + 1
    @test needed_properties(o) == (:a,)
    @test o((a=2,)) == 3

    @test_throws "Cannot determine" needed_properties(@o _ + 1)
    @test_throws "Cannot determine" needed_properties(@o _[1] + 1)

    o = @o _.a + _.b.c
    @test needed_properties(o) == needed_properties(typeof(o)) == (:a, :b)
    @test o((a=2, b=(c=3,))) == 5

    o = @o exp10(_.a + _.b.c)
    @test needed_properties(o) == (:a, :b)
    @test o((a=2, b=(c=3,))) == 10^5

    o = @o round(Int, _.a + _.b.c)
    @test needed_properties(o) == (:a, :b)
    @test o((a=2.6, b=(c=3,))) == 6

    macro mym_str(expr)
        expr
    end
    begin
        o = @o _.a + _.b + parse(Int, mym"3")
        @test needed_properties(o) == (:a, :b)
        @test o((a=1, b=2)) == 6
    end

    o = @o _ + _ + 1
    @test_throws "Cannot determine" needed_properties(o)
    @test o(2) == 5

    o = @o _.a + _[2] + 1
    @test_throws "Cannot determine" needed_properties(o)
    @test o((a=10, b=100)) == 111
end

@testitem "concat optics" begin
    @testset for o in (
        @o(_.a) ++ @o(_.b),
        @optics(_.a, _.b),
        @o(_[(:a, :b)] |> Elements()),
    )
        obj = (a=1, b=2, c=3)
        @test getall(obj, o) === (1, 2)
        @test setall(obj, o, (3, 4)) === (a=3, b=4, c=3)
        @test modify(-, obj, o) === (a=-1, b=-2, c=3)
        Accessors.test_getsetall_laws(o, obj, (3, 4), (:a, :b))
    end

    obj = (a=1, bs=((c=2, d=3), (c=4, d=5)))
    o = concat(a=@o(_.a), c=@o(first(_.bs) |> _.c))
    AccessorsExtra.@allinferred getall modify delete if VERSION >= v"1.10-"; :setall end begin
        @test getall(obj, o) === (a=1, c=2)
        @test setall(obj, o, (a="10", c="11")) === (a="10", bs=((c="11", d=3), (c=4, d=5)))
        @test setall(obj, o, (c="11", a="10")) === (a="10", bs=((c="11", d=3), (c=4, d=5)))
        @test modify(float, obj, o) === (a=1.0, bs=((c=2.0, d=3), (c=4, d=5)))
        # doesn't infer due to "bounded recursion
        @test_broken delete(obj, o) === (bs=((d=3,), (c=4, d=5)),)
    end
    @test delete(obj, o) === (bs=((d=3,), (c=4, d=5)),)
    

    AccessorsExtra.@allinferred getall setall modify begin
        obj = (a=1, bs=((c=2, d=3), (c=4, d=5)))
        o = @optics _.a  _.bs |> Elements() |> _.c
        @test getall(obj, o) === (1, 2, 4)
        @test setall(obj, o, (:a, :b, :c)) === (a=:a, bs=((c=:b, d=3), (c=:c, d=5)))
        @test modify(-, obj, o) === (a=-1, bs=((c=-2, d=3), (c=-4, d=5)))
        Accessors.test_getsetall_laws(o, obj, (3, 4, 5), (:a, :b, :c))

        o = @o(_ - 1) ∘ (@optics _.a  _.bs |> Elements() |> _.c)
        @test getall(obj, o) === (0, 1, 3)
        @test modify(-, obj, o) === (a=1, bs=((c=0, d=3), (c=-2, d=5)))
        Accessors.test_getsetall_laws(o, obj, (3, 4, 5), (10, 20, 30))

        obj = (a=1, bs=[(c=2, d=3), (c=4, d=5)])
        o = @optics _.a  _.bs |> Elements() |> _.c
        @test getall(obj, o) == [1, 2, 4]
        @test modify(-, obj, o) == (a=-1, bs=[(c=-2, d=3), (c=-4, d=5)])
    end
    @test setall(obj, o, (:a, :b, :c)) == (a=:a, bs=[(c=:b, d=3), (c=:c, d=5)])

    @test getall((1,2), ++()) === (;)
    @test setall((1,2), ++(), ()) === (1,2)
    @test setall((1,2), AccessorsExtra.ConcatOptics((;)), (;)) === (1,2)
    @test getall((1,2), ++() ∘ identity) === ()
    @test setall((1,2), ++() ∘ identity, ()) === (1,2)
    @test setall((1,2), AccessorsExtra.ConcatOptics((;)) ∘ identity, (;)) === (1,2)
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

@testitem "shorter aliases" begin
    @test @o(_.a[∗].b[∗ₚ].c[2]) === @optic(_.a |> Elements() |> _.b |> Properties() |> _.c[2])
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

    @test modify(+, (1, 2), keyed(∗), (3, 4)) === (4, 6)
    @test modify(+, (1, 2), keyed(∗), [3, 4, 5]) === (4, 6)
    @test modify(+, [1, 2], keyed(∗), (3, 4, 5)) == [4, 6]
    @test modify(+, [1, 2], keyed(∗), [3, 4]) == [4, 6]
    @test modify(+, (x=1, y=2), keyed(∗), (x=3, y=4, z=5)) === (x=4, y=6)
    @test modify(+, (x=1, y=2), keyed(∗), (y=4, x=3, z=5)) === (x=4, y=6)
    @test modify(+, (x=1, y=2), keyed(∗), Dict(:y=>4, :x=>3, :z=>5)) === (x=4, y=6)
    @test modify(+, (x=1, y=2), keyed(∗), dictionary([:y=>4, :x=>3])) === (x=4, y=6)
    @test_throws Exception modify(+, (1, 2), keyed(∗), (a=3, b=4))
    @test_throws Exception modify(+, (x=1, y=2), keyed(∗), (3, 4))
    @test_throws Exception modify(+, (x=1, y=2), keyed(∗), (a=3, b=4))

    @test modify(+, Dictionary([2, 3], [10, 20]), ∗, 1:5)::Dictionary == Dictionary([2, 3], [11, 22])
    @test modify(+, Dictionary([2, 3], [10, 20]), keyed(∗), 1:5)::Dictionary == Dictionary([2, 3], [12, 23])
    @test modify(+, ArrayDictionary([2, 3], [10, 20]), ∗, 1:5)::ArrayDictionary == Dictionary([2, 3], [11, 22])
    @test_broken modify(+, ArrayDictionary([2, 3], [10, 20]), keyed(∗), 1:5)::ArrayDictionary == Dictionary([2, 3], [12, 23])
    @test modify(+, unioncollection(Dictionary([2, 3], [10, 20])), ∗, 1:5)::UnionDictionary == Dictionary([2, 3], [11, 22])
    @test modify(+, unioncollection(Dictionary([2, 3], [10, 20])), keyed(∗), 1:5)::UnionDictionary == Dictionary([2, 3], [12, 23])
    end
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
    o = @o _("abc")
    @test o == AccessorsExtra.funcvallens("abc")
    @test o(reverse) == "cba"
    myrev = set(reverse, o, "!!!")
    @test myrev("abc") == "!!!"
    @test myrev("def") == "fed"

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

    @test (@maybe _.a) === maybe(@o _.a)
    @test (@maybe _.a[∗][2]) === maybe(@o _.a[∗][2])
    @test (@maybe exp(_.a[∗][2])) === maybe(@o exp(_.a[∗][2]))
    @test (@maybe _.a 10) === maybe(@o _.a; default=10)

    x = (a=[1, 2],)
    @test (@oget x.a[2] 123) === 2
    @test (@oget x.a[3] 123) === 123

    @test osomething(@o(_.a)) === @osomething _.a
    @test osomething(@o(_.a), @o(_.b)) === @osomething _.a _.b
end

@testitem "recursive" begin
    using StaticArrays

    AccessorsExtra.@allinferred set modify getall setall begin

    or = RecursiveOfType(Number)
    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx")))
    @test getall(m, or) == (1, 1, 3)
    @test modify(x->x+10, m, or) === (a=11, bs=((c=11, d="2"), (c=13, d="xxx")))
    @test setall(m, or, (10, 20, 30)) === (a=10, bs=((c=20, d="2"), (c=30, d="xxx")))
    @test setall(m, or, [10, 20, 30]) === (a=10, bs=((c=20, d="2"), (c=30, d="xxx")))
    @test set(m, or, 123) === (a=123, bs=((c=123, d="2"), (c=123, d="xxx")))

    m = (a=1, bs=[(c=1, d="2"), (c=3, d="xxx")])
    @test getall(m, or) == [1, 1, 3]
    @test modify(x->x+10, m, or) == (a=11, bs=[(c=11, d="2"), (c=13, d="xxx")])
    @test_throws Exception setall(m, or, [10, 20, 30])  # setall not supported with dynamic length vectors

    m = (a=1, bs=SVector((c=1, d="2"), (c=3, d="xxx")))
    @test getall(m, or) === (1, 1, 3)
    @test modify(x->x+10, m, or) === (a=11, bs=SVector((c=11, d="2"), (c=13, d="xxx")))
    @test setall(m, or, (10, 20, 30)) === (a=10, bs=SVector((c=20, d="2"), (c=30, d="xxx")))

    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx")))
    or = RecursiveOfType(NamedTuple)
    @test getall(m, or) === ((c = 1, d = "2"), (c = 3, d = "xxx"), m)
    @test modify(Dict ∘ pairs, m, or) == Dict(:a => 1, :bs => (Dict(:d => "2", :c => 1), Dict(:d => "xxx", :c => 3)))

    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx", e=((;),))))
    @test getall(m, or) === ((c = 1, d = "2"), (;), (c = 3, d = "xxx", e = ((;),)), (a = 1, bs = ((c = 1, d = "2"), (c = 3, d = "xxx", e = ((;),)))))

    m = (a=1, b=2+3im)
    or = RecursiveOfType(Real)
    @test getall(m, or) == (1, 2, 3)
    @test modify(x->x+10, m, or) == (a=11, b=12+13im)
    @test setall(m, or, (10, 20, 30)) == (a=10, b=20+30im)

    end

    # or = keyed(RecursiveOfType(Number))
    # m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx")))
    # @test getall(m, or) == (1, 1, 3)
end

@testitem "context" begin
    AccessorsExtra.@allinferred modify begin
    obj = ((a='a',), (a='b',), (a='c',))
    o = keyed(Elements()) ⨟ @o(_.a)
    @test modify(((i, v),) -> i => v, obj, o) == ((a=1=>'a',), (a=2=>'b',), (a=3=>'c',))
    o = keyed(Elements()) ⨟ @o(_.a) ⨟ @o(convert(Int, _) + 1)
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((1, 98), (2, 99), (3, 100))
    @test modify(((i, v),) -> i + v, obj, o) == ((a='b',), (a='d',), (a='f',))
    o = Elements() ⨟ keyed(Elements())
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((:a, 'a'), (:a, 'b'), (:a, 'c'))
    @test modify(((i, v),) -> v, obj, o) == obj
    o = Elements() ⨟ keyed(Properties())
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((:a, 'a'), (:a, 'b'), (:a, 'c'))
    @test modify(((i, v),) -> v, obj, o) == obj

    o = enumerated(Elements()) ⨟ Elements()
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((1, 'a'), (2, 'b'), (3, 'c'))
    @test modify(((i, v),) -> v, obj, o) == obj
    o = enumerated(Elements() ⨟ Properties())
    @test_broken map(x -> (x.ctx, x.v), getall(obj, o)) == ((1, 'a'), (2, 'b'), (3, 'c'))
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == [(1, 'a'), (2, 'b'), (3, 'c')]
    @test modify(((i, v),) -> v, obj, o) == obj
    o = Elements() ⨟ enumerated(Properties())
    @test_broken map(x -> (x.ctx, x.v), getall(obj, o)) == ((1, 'a'), (1, 'b'), (1, 'c'))
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == [(1, 'a'), (1, 'b'), (1, 'c')]
    @test modify(((i, v),) -> v, obj, o) == obj
    end

    o = @o(_.b) ⨟ keyed(Elements()) ⨟ @o(_.a)
    @test modify(((i, v),) -> i => v, (a=1, b=((a='a',), (a='b',), (a='c',))), o) == (a=1, b=((a=1=>'a',), (a=2=>'b',), (a=3=>'c',)))
    @test modify(((i, v),) -> i => v, (a=1, b=[(a='a',), (a='b',), (a='c',)]), o) == (a=1, b=[(a=1=>'a',), (a=2=>'b',), (a=3=>'c',)])
    @test modify(
        wix -> wix.ctx => wix.v,
        (a=1, b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        keyed(@o(_.a)) ++ keyed(@o(_.b)) ⨟ @o(_[∗].a)
    ) == (a=:a=>1, b=(x=(a=:b=>'a',), y=(a=:b=>'b',), z=(a=:b=>'c',)))
    @test modify(
        wix -> wix.ctx => wix.v,
        (a=[(a=1,)], b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        (keyed(@o(_.a)) ++ keyed(@o(_.b))) ⨟ @o(_[∗].a)ᵢ
    ) == (a=[(a=:a=>1,)], b=(x=(a=:b=>'a',), y=(a=:b=>'b',), z=(a=:b=>'c',)))
    @test modify(
        wix -> wix.ctx => wix.v,
        (a=1, b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        @o(_.b) ⨟ keyed(Elements()) ⨟ Elements()
    ) == (a=1, b=(x=(a=:x=>'a',), y=(a=:y=>'b',), z=(a=:z=>'c',)))

    AccessorsExtra.@allinferred modify begin
    @test modify(
        wix -> wix.v / wix.ctx.total,
        ((x=5, total=10,), (x=2, total=20,), (x=3, total=8,)),
        Elements() ⨟ selfcontext() ⨟ @o(_.x)
    ) == ((x=0.5, total=10,), (x=0.1, total=20,), (x=0.375, total=8,))
    @test modify(
        wix -> wix.v / wix.ctx,
        ((x=5, total=10,), (x=2, total=20,), (x=3, total=8,)),
        Elements() ⨟ selfcontext(r -> r.total) ⨟ @o(_.x)
    ) == ((x=0.5, total=10,), (x=0.1, total=20,), (x=0.375, total=8,))

    str = "abc def 5 x y z 123"
    o = @o(eachmatch(r"\w+", _)) ⨟ enumerated(Elements())
    @test map(wix -> "$(wix.v.match)_$(wix.ctx)", getall(str, o)) == ["abc_1", "def_2", "5_3", "x_4", "y_5", "z_6", "123_7"]
    @test modify(
        wix -> "$(wix.v.match)_$(wix.ctx)",
        str,
        o
    ) == "abc_1 def_2 5_3 x_4 y_5 z_6 123_7"
    @test modify(
        wix -> wix.v + wix.ctx,
        str,
        @o(eachmatch(r"\d+", _)) ⨟ enumerated(Elements()) ⨟ @o(parse(Int, _.match))
    ) == "abc def 6 x y z 125"
    @test modify(
        wix -> "$(wix.ctx):$(wix.v)",
        "2022-03-15",
        @o(match(r"(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})", _)) ⨟ keyed(Elements())
    ) == "y:2022-m:03-d:15"
    end

    data = [
        (a=1, bs=[10, 11, 12]),
        (a=2, bs=[20, 21]),
    ]
    o = @o _[∗] |> selfcontext() |> _.bs[∗]
    @test map(x -> (;x.ctx.a, b=x.v), getall(data, o)) == [(a = 1, b = 10), (a = 1, b = 11), (a = 1, b = 12), (a = 2, b = 20), (a = 2, b = 21)]
    @test modify(x -> 100*x.ctx.a + x.v, data, o) == [
        (a=1, bs=[110, 111, 112]),
        (a=2, bs=[220, 221]),
    ]

    o = keyed(∗) ⨟ @o(_.bs) ⨟ keyed(∗)
    @test map(x -> (x.ctx[1], x.ctx[2], x.v), getall(data, o)) == [(1, 1, 10), (1, 2, 11), (1, 3, 12), (2, 1, 20), (2, 2, 21)]
    @test modify(x -> (x.ctx[1], x.ctx[2], x.v), data, o) == [(a = 1, bs = [(1, 1, 10), (1, 2, 11), (1, 3, 12)]), (a = 2, bs = [(2, 1, 20), (2, 2, 21)])]
    o = keyed(∗) ⨟ keyed(@o(_.bs)) ⨟ keyed(∗)
    @test map(x -> (x.ctx..., x.v), getall(data, o)) == [(1, :bs, 1, 10), (1, :bs, 2, 11), (1, :bs, 3, 12), (2, :bs, 1, 20), (2, :bs, 2, 21)]
    @test modify(x -> (x.ctx..., x.v), data, o) ==
        [(a = 1, bs = [(1, :bs, 1, 10), (1, :bs, 2, 11), (1, :bs, 3, 12)]), (a = 2, bs = [(2, :bs, 1, 20), (2, :bs, 2, 21)])]
end

@testitem "stripcontext" begin
    using AccessorsExtra: decompose, ConcatOptics
    (==ᶠ(x::T, y::T) where {T}) = x === y
    ==ᶠ(x, y) = all(filter(!=(identity), decompose(x)) .==ᶠ filter(!=(identity), decompose(y)))
    ==ᶠ(x::ConcatOptics, y::ConcatOptics) = all(x.optics .==ᶠ y.optics)

    @testset for o in (
        log,
        (@o _.a),
        (@o _[∗].a),
        (@o _[∗].a) ++ (@o _[1]),
    )
        @test !hascontext(o)
        @test stripcontext(o) === o
    end
    @testset for o in (
        (@o _.a) |> enumerated,
        (@o _[∗].a) |> enumerated,
        (@o _ |> enumerated(∗) |> _.a),
        (@o _ |> keyed(∗) |> _.a),
        ((@o _[∗].a) ++ (@o _[1])) |> enumerated,
        ((@o _[∗].a) ++ (@o _[1])) |> selfcontext,
        ((@o _ |> keyed(∗) |> _.a) ++ keyed(@o _[1])) |> enumerated,
        ((@o _ |> keyed(∗) |> _.a) ++ keyed(@o _[1])),
    )
        @test hascontext(o)
        @test stripcontext(o) != o
    end

    @test stripcontext((a=1, b=:x)) === (a=1, b=:x)
    @test stripcontext(AccessorsExtra.ValWithContext(1, 2)) === 2
    @test stripcontext(keyed(Elements())) ==ᶠ Elements()
    @test stripcontext(keyed(Elements()) ∘ @o(_.a)) ==ᶠ Elements() ∘ @o(_.a)
    @test stripcontext(keyed(Elements()) ∘ @o(_.a) ∘ @o(_.b)) ==ᶠ Elements() ∘ @o(_.a) ∘ @o(_.b)
    @test stripcontext(Elements() ∘ keyed(Elements()) ∘ @o(_.a) ∘ @o(convert(Int, _) + 1)) ==ᶠ Elements() ∘ Elements() ∘ @o(_.a) ∘ @o(convert(Int, _) + 1)
    @test stripcontext((keyed(@o(_.a)) ++ keyed(@o(_.b))) ∘ @o(_[∗].a)ᵢ) ==ᶠ (@o(_.a) ++ @o(_.b)) ∘ @o(_[∗].a)
    @test stripcontext(Elements() ∘ selfcontext(r -> r.total) ∘ @o(_.x)) ==ᶠ Elements() ∘ @o(_.x)
    re = r"\d+"
    @test stripcontext(@o(eachmatch(re, _)) ∘ enumerated(Elements()) ∘ @o(parse(Int, _.match))) ==ᶠ @o(eachmatch(re, _)) ∘ Elements() ∘ @o(parse(Int, _.match))

    Accessors.test_getset_laws(stripcontext, @o(_.a), (@o _.x), identity)
    Accessors.test_getset_laws(stripcontext, keyed(Elements()), (@o _.x), identity)
    Accessors.test_getset_laws(stripcontext, selfcontext(x -> x + 1), identity, identity)
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

@testitem "replace" begin
    nt = (a=1, b=:x)
    AccessorsExtra.@allinferred _replace begin
        @test AccessorsExtra._replace(nt, @o(_.a) => @o(_.c)) === (c=1, b=:x)
        @test AccessorsExtra._replace(nt, (@o(_.a) => @o(_.c)) ∘ identity) === (c=1, b=:x)
    end
    @test @replace(nt.c = nt.a) === (c=1, b=:x)
    @test @replace(nt.c = _.a) === (c=1, b=:x)
    @test @replace(_.c = nt.a) === (c=1, b=:x)
    @test @replace(nt |> (_.c = _.a)) === (c=1, b=:x)

    @test_throws Exception eval(:(@replace(nt_1.c = nt_2.a)))
    @test_throws Exception eval(:(@replace(_.c = _.a)))
end

@testitem "push, pop" begin
    obj = (a=1, b=(2, 3))
    @test @push(obj.b, 4) == (a=1, b=(2, 3, 4))
    @test @pushfirst(obj.b, 4) == (a=1, b=(4, 2, 3))
    # these return obj, as in StaticArrays:
    @test @pop(obj.b) == (a=1, b=(2,))
    @test @popfirst(obj.b) == (a=1, b=(3,))
end

@testitem "base optics" begin
    using StaticArrays
    using LinearAlgebra: norm

    x = [1, 2, 3]
    @test (@set (2 in $x) = false) == [1, 3]
    @test (@set (5 in $x) = true) == [1, 2, 3, 5]
    Accessors.test_getset_laws(@o(2 in _), [1,2,3], false, true)
    Accessors.test_getset_laws(@o(5 in _), [1,2,3], false, true)
    Accessors.test_getset_laws(@o(2 in _), Set([1,2,3]), false, true)
    Accessors.test_getset_laws(@o(5 in _), Set([1,2,3]), false, true)

    ≈ₜ(x::T, y::T) where {T} = all(x .≈ y)
    Accessors.test_getset_laws(@o(atan(_...)), (1., 2.), 1.2, 3.4; cmp=(≈ₜ))
    Accessors.test_getset_laws(@o(atan(_...)), [1., 2.], 1.2, 3.4; cmp=(≈ₜ))
    Accessors.test_getset_laws(@o(atan(_...)), SVector(1., 2.), 1.2, 3.4; cmp=(≈ₜ))
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

@testitem "construct" begin
    using StaticArrays
    using StaticArrays: norm

    ==ₜ(_, _) = false
    ==ₜ(x::T, y::T) where T = x == y

    @testset "basic usage" begin
        AccessorsExtra.@allinferred construct begin
            @test construct(Complex, @o(_.re) => 1, @o(_.im) => 2)::Complex{Int} === 1 + 2im
            @test_broken construct(Complex, @o(_.im) => 1, @o(_.re) => 2)::Complex{Int} === 1 + 2im
            @test construct(ComplexF32, @o(_.re) => 1, @o(_.im) => 2)::ComplexF32 === 1f0 + 2f0im
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

            @test construct(NamedTuple, @o(_.a) => 1, @o(_.b) => "") === (a=1, b="")
        end
    end

    @testset "laws" begin
        using AccessorsExtra: test_construct_laws

        test_construct_laws(Complex, @o(_.re) => 1, @o(_.im) => 2)
        test_construct_laws(Complex{Int}, @o(_.re) => 1, @o(_.im) => 2)
        test_construct_laws(ComplexF32, @o(_.re) => 1, @o(_.im) => 2)
        test_construct_laws(Complex, @o(_.re) => 1., @o(_.im) => 2)
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
        test_construct_laws(NamedTuple, @o(_.a) => 1)
        test_construct_laws(NamedTuple, @o(_.a) => 1, @o(_.b) => "")

        @testset for T in (Tuple{}, SVector{0}, SVector{0,String})
            test_construct_laws(T)
        end
        @testset for T in (Tuple{Any}, Tuple{Int}, Tuple{Float32}, Tuple{Real}, SVector{1}, SVector{1,Int}, SVector{1,Float64})
            test_construct_laws(T, only => 2)
            test_construct_laws(T, first => 3)
            test_construct_laws(T, last => 4)
        end
        @testset for T in (Tuple{Any,Any}, Tuple{Float64,Float32}, Tuple{Real,Real}, SVector{2}, SVector{2,Float32}, SVector{2,Float64})
            test_construct_laws(T, first => 4, last => 5)
            test_construct_laws(T, norm => 3, @o(atan(_...)) => 0.123; cmp=(x,y) -> isapprox(x,y,rtol=√eps(Float32)))
            test_construct_laws(T, norm => 3, @o(atan(_...)) => 0.123; cmp=(x,y) -> isapprox(x,y,rtol=√eps(Float32)))
        end
        test_construct_laws(SVector{2}, @o(_.x) => 4, @o(_.y) => 5)
        test_construct_laws(SVector{2}, @o(_.y) => 4, @o(_.x) => 5)
        test_construct_laws(SVector{2,Float32}, @o(_.x) => 4, @o(_.y) => 5)
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
            _.a = construct(Complex, @o(_.re) => -1, @o(_.im) => 0)
            _.b = construct(Vector, only => 10)
            _.c = 123
        end
        @test res == (a=-1, b=[10], c=123)
    end

    @testset "invertible pre-func" begin
        using AccessorsExtra: test_construct_laws

        AccessorsExtra.@allinferred construct begin

        @test construct(Complex, abs => 3, rad2deg ∘ angle => 45) ≈ 3/√2 * (1 + 1im)
        test_construct_laws(SVector{2,Float32}, norm => 3, @o(atan(_...) |> rad2deg) => 0.123; cmp=(≈))

        res = @construct SVector{2} begin
            norm(_) = 3
            atan(_...) |> rad2deg |> _ + 1 = 46
        end
        @test res ≈ SVector(3, 3) / √2
        
        end
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

@testitem "uris" begin
    using URIs

    uri = URI("https://google.com/user?key=value")
    @test (@set uri.host = "github.com") == URI("https://github.com/user?key=value")
    @test (@set uri.path = "/abc/def") == URI("https://google.com/abc/def?key=value")
    @test URIs.uristring(@set uri.path = "/abc/def") == "https://google.com/abc/def?key=value"
end

@testitem "staticarrays" begin
    using StaticArrays

    Accessors.test_getset_laws(Tuple, SVector(1, 2, 3), (4., 5, 6), (:a, :b, :c))
    Accessors.test_getset_laws(SVector, (1, 2, 3), SVector(4., 5, 6), SVector(:a, :b, :c))
    Accessors.test_getset_laws(SVector, (1., 2, 3), SVector(4., 5, 6), SVector(:a, :b, :c))
end

@testitem "domainsets" begin
    using DomainSets; using DomainSets: ×
    using StaticArrays

    Accessors.test_getset_laws(components, (1..2) × (2..5), SVector((10.0..20.0), (1..0)), SVector((-1..1) × (0..2)))
    # Accessors.test_getset_laws(components, (1..2) × (2..5), ((10.0..20.0), (1..0)), ((-1..1) × (0..2)))
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
    InverseFunctions.test_inverse(@o(eachslice(_, dims=1)), A)
    InverseFunctions.test_inverse(@o(eachslice(_, dims=2)), A)
    InverseFunctions.test_inverse(@o(eachslice(_, dims=2, drop=true)), A)
    InverseFunctions.test_inverse(@o(eachslice(_, dims=2, drop=false)), A)

    @test @modify(x -> x / sum(x), A |> eachslice(_, dims=1)[∗]) == [1/6 2/6 3/6; 4/15 5/15 6/15]
    @test @modify(x -> x / sum(x), A |> eachslice(_, dims=2)[∗]) == [1/5 2/7 3/9; 4/5 5/7 6/9]

    A = reshape(1:24, 2, 1, 3, 4)
    for d in 1:4
        InverseFunctions.test_inverse(@o(eachslice(_, dims=d)), A)
        InverseFunctions.test_inverse(@o(eachslice(_, dims=d, drop=true)), A)
        InverseFunctions.test_inverse(@o(eachslice(_, dims=d, drop=false)), A)
    end
end

@testitem "inverses" begin
    using InverseFunctions
    using Unitful
    using Distributions

    InverseFunctions.test_inverse(Base.Fix1(getindex, [4, 5, 6]), 2)
    InverseFunctions.test_inverse(Base.Fix1(getindex, Dict(2 => 123, 3 => 456)), 2)


    # https://github.com/JuliaStats/Distributions.jl/pull/1685
    using Distributions
    @testset for d in (Normal(1.5, 2.3),)
        # unbounded distribution: can invert cdf at any point in [0..1]
        @testset for f in (cdf, ccdf, logcdf, logccdf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 1.2345)
            InverseFunctions.test_inverse(Base.Fix1(f, d), -Inf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), Inf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), -1.2345)
            @test_throws "not defined at 5" inverse(Base.Fix1(f, d))(5)
        end
    end
    @testset for d in (Uniform(1, 2), truncated(Normal(1.5, 2.3), 1, 2))
        # bounded distribution: cannot invert cdf at 0 and 1
        @testset for f in (cdf, ccdf, logcdf, logccdf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 1.2345)
            @test_throws "not defined at 5" inverse(Base.Fix1(f, d))(5)
            @test_throws "not defined at 0" inverse(Base.Fix1(f, d))(0)
            @test_throws "not defined at 1" inverse(Base.Fix1(f, d))(1)
        end
    end

    @testset for d in (Normal(1.5, 2.3), Uniform(1, 2), truncated(Normal(1.5, 2.3), 1, 2))
        # quantile can be inverted everywhere for any continuous distribution
        @testset for f in (quantile, cquantile)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 0.1234)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 0)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 1)
        end
        @testset for f in (invlogcdf, invlogccdf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), -0.1234)
            InverseFunctions.test_inverse(Base.Fix1(f, d), -Inf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 0)
        end
    end
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

    # @test modify(b -> b < 15 ? b : nothing, data, @o(_[∗].bs |> Wither())) == [(a = 1, bs = [10, 11, 12]), (a = 2, bs = Nothing[])]
    # @test modify(b -> b < 15 ? b : nothing, data, @o _ |> Wither() |> _.bs |> Wither()) == [(a = 1, bs = [10, 11, 12])]

    AccessorsExtra.@allinferred modify begin
        T = (4, 5, 6)
        @test (8, 10, 12) === modify(x -> 2x, T, @o values(_)[∗])
        @test (5, 7, 9) === modify(((i, x),) -> i => i + x, T, @o pairs(_)[∗])
        @test_throws AssertionError @modify(((i, x),) -> (i+1) => i + x, T |> @o pairs(_)[∗])
        T = (a=4, b=5, c=6)
        @test (a=8, b=10, c=12) === modify(x -> 2x, T, @o values(_)[∗])
        @test (aa=4, bb=5, cc=6) === modify(x -> Symbol(x, x), (a=4, b=5, c=6), @o keys(_)[∗])  broken=VERSION < v"1.10-"
        @test (a=(:a, 8), b=(:b, 10), c=(:c, 12)) === modify(((i, x),) -> i => (i, 2x), T, @o pairs(_)[∗])
        A = [4, 5, 6]
        @test [8, 10, 12] == modify(x -> 2x, A, @o values(_)[∗])
        @test [5, 7, 9] == modify(((i, x),) -> i => i + x, A, @o pairs(_)[∗])
        D = Dict(4 => 5, 6 => 7)
        @test Dict(4 => 6, 6 => 8) == modify(x -> x+1, D, @o values(_)[∗])
        @test Dict(5 => 5, 7 => 7) == modify(x -> x+1, D, @o keys(_)[∗])
        @test Dict(8 => 9, 12 => 13) == modify(((i, x),) -> 2i => i + x, D, @o pairs(_)[∗])
        D = dictionary([4 => 5, 6 => 7])
        @test dictionary([4 => 6, 6 => 8]) == modify(x -> x+1, D, @o values(_)[∗])
        @test dictionary([5 => 5, 7 => 7]) == modify(x -> x+1, D, @o keys(_)[∗])
        @test dictionary([8 => 9, 12 => 13]) == modify(((i, x),) -> 2i => i + x, D, @o pairs(_)[∗])
        D = ArrayDictionary([4, 6], [5, 7])
        @test dictionary([4 => 6, 6 => 8]) == modify(x -> x+1, D, @o values(_)[∗])
        @test dictionary([5 => 5, 7 => 7]) == modify(x -> x+1, D, @o keys(_)[∗])
    end
    @test (aa=4, bb=5, cc=6) === modify(x -> Symbol(x, x), (a=4, b=5, c=6), @o keys(_)[∗])
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

@testitem "_" begin
    import CompatHelperLocal as CHL
    CHL.@check()

    using Aqua
    Aqua.test_all(AccessorsExtra, piracy=false, ambiguities=false)
end
