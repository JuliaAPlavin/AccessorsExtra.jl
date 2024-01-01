using TestItems
using TestItemRunner
@run_package_tests


@testitem "concat optics" begin
    @testset for o in (
        @optic(_.a) ++ @optic(_.b),
        @optic(_[(:a, :b)] |> Elements()),
    )
        obj = (a=1, b=2, c=3)
        @test getall(obj, o) === (1, 2)
        @test setall(obj, o, (3, 4)) === (a=3, b=4, c=3)
        @test modify(-, obj, o) === (a=-1, b=-2, c=3)
        Accessors.test_getsetall_laws(o, obj, (3, 4), (:a, :b))
    end

    AccessorsExtra.@allinferred getall setall modify begin
        obj = (a=1, bs=((c=2, d=3), (c=4, d=5)))
        o = @optic(_.a) ++ @optic(_.bs |> Elements() |> _.c)
        @test getall(obj, o) === (1, 2, 4)
        @test setall(obj, o, (:a, :b, :c)) === (a=:a, bs=((c=:b, d=3), (c=:c, d=5)))
        @test modify(-, obj, o) === (a=-1, bs=((c=-2, d=3), (c=-4, d=5)))
        Accessors.test_getsetall_laws(o, obj, (3, 4, 5), (:a, :b, :c))

        o = @optic(_ - 1) ∘ (@optic(_.a) ++ @optic(_.bs |> Elements() |> _.c))
        @test getall(obj, o) === (0, 1, 3)
        @test modify(-, obj, o) === (a=1, bs=((c=0, d=3), (c=-2, d=5)))
        Accessors.test_getsetall_laws(o, obj, (3, 4, 5), (10, 20, 30))

        obj = (a=1, bs=[(c=2, d=3), (c=4, d=5)])
        o = @optic(_.a) ++ @optic(_.bs |> Elements() |> _.c)
        @test getall(obj, o) == [1, 2, 4]
        @test modify(-, obj, o) == (a=-1, bs=[(c=-2, d=3), (c=-4, d=5)])
    end
    @test setall(obj, o, (:a, :b, :c)) == (a=:a, bs=[(c=:b, d=3), (c=:c, d=5)])
end

@testitem "shorter forms" begin
    @test @optic(_.a[∗].b.:∗.c[2]) === @optic(_.a |> Elements() |> _.b |> Properties() |> _.c[2])
end

@testitem "replace" begin
    nt = (a=1, b=:x)
    @test AccessorsExtra._replace(nt, @optic(_.a) => @optic(_.c)) === (c=1, b=:x)
    @test AccessorsExtra._replace(nt, (@optic(_.a) => @optic(_.c)) ∘ identity) === (c=1, b=:x)
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

@testitem "staticarrays" begin
    using StaticArrays: SVector, MVector

    sv = SVector(1, 2)
    @test SVector(3.0, 2.0) === @set sv.x = 3.0
    @test SVector(3.0, 5.0) === @inferred setproperties(sv, x = 3.0, y = 5.0)
    @test SVector(-1.0, -2.0) === @set sv.data = (-1.0, -2)

    @test_throws "does not have properties (:z,)" @set sv.z = 3.0
end

@testitem "structarrays" begin
    using StructArrays

    struct S{TA, TB}
        a::TA
        b::TB
    end

    s = StructArray(a=[1, 2, 3])
    @test @insert(StructArrays.components(s).b = 10:12)::StructArray == [(a=1, b=10), (a=2, b=11), (a=3, b=12)]
    @test setproperties(s, a=10:12)::StructArray == StructArray(a=10:12)
    @test_throws ArgumentError setproperties(s, b=10:12)
    @test @set(s.a = 10:12)::StructArray == StructArray(a=10:12)
    @test @insert(s.b = 10:12)::StructArray == [(a=1, b=10), (a=2, b=11), (a=3, b=12)]
    @test @delete(@insert(s.b = 10:12).a)::StructArray == StructArray(b=10:12)
    @test_throws "only eltypes with fields" @delete(s.a)

    s = StructArray([(a=(x=1, y=:abc),), (a=(x=2, y=:def),)]; unwrap=T -> T <: NamedTuple)
    @test @set(s.a = 10:12)::StructArray == StructArray(a=10:12)
    @test @set(s.a.x = 10:11)::StructArray == [(a=(x=10, y=:abc),), (a=(x=11, y=:def),)]
    @test @insert(s.b = 10:11)::StructArray == [(a=(x=1, y=:abc), b=10), (a=(x=2, y=:def), b=11)]
    @test @insert(s.a.z = 10:11)::StructArray == [(a=(x=1, y=:abc, z=10),), (a=(x=2, y=:def, z=11),)]
    @test @delete(s.a.y)::StructArray == [(a=(x=1,),), (a=(x=2,),)]
    @test @replace(s.b = s.a.x)::StructArray == [(a=(y=:abc,), b=1), (a=(y=:def,), b=2)]

    s = StructArray([S(1, 2), S(3, 4)])
    @test @set(s.a = 10:11)::StructArray == StructArray([S(10, 2), S(11, 4)])
    @test_broken @set(s.a = [:a, :b])::StructArray == StructArray([S(:a, 2), S(:b, 4)])
    # @test @set(s.a.x = 10:11)::StructArray == [(a=(x=10, y=:abc),), (a=(x=11, y=:def),)]
    # @test @insert(s.b = 10:11)::StructArray == [(a=(x=1, y=:abc), b=10), (a=(x=2, y=:def), b=11)]
    # @test @insert(s.a.z = 10:11)::StructArray == [(a=(x=1, y=:abc, z=10),), (a=(x=2, y=:def, z=11),)]
    # @test @delete(s.a.y)::StructArray == [(a=(x=1,),), (a=(x=2,),)]
    # @test @replace(s.b = s.a.x)::StructArray == [(a=(y=:abc,), b=1), (a=(y=:def,), b=2)]
end

@testitem "getfield" begin
    t = (x=1, y=2)
    @test set(t, @optic(getfield(_, :x)), :hello) === (x=:hello, y=2)
    @test_throws Exception set(t, @optic(getfield(_, :z)), 3)
end

@testitem "view" begin
    A = [1, 2, (a=3, b=4)]
    opt = @optic _ |> ViewLens(3) |> _.a
    @test opt(A) == 3
    @test set(A, opt, 10) === A == [1, 2, (a=10, b=4)]
    @test set(A, ViewLens((1:2,)), [-2, -3]) === A == [-2, -3, (a=10, b=4)]
    @test @modify(x -> 2x, A |> ViewLens((1:2,))) === A == [-4, -6, (a=10, b=4)]
    Accessors.test_getset_laws(opt, A, "a", :b)
    Accessors.test_getset_laws(@optic(_ |> ViewLens((1:2,))), A, [5, 6], [7, 8])

    A = [1, 2, (a=3, b=4)]
    @test set(A, @optic(view(_, 1:2)), [-2, -3]) === A == [-2, -3, (a=3, b=4)]
    @test @modify(x -> 2x, A |> view(_, 1:2)) === A == [-4, -6, (a=3, b=4)]
    @test @modify(x -> x + 1, A |> view(_, 1:2) |> Elements()) === A == [-3, -5, (a=3, b=4)]
end

@testitem "ranges" begin
    r = 1:10
    @test 1:3:10 === @set step(r) = 3
    @test 1:0.5:10 === @set length(r) = 19
    @test -5:10 === @set first(r) = -5
    @test 1:15 === @set last(r) = 15

    r = range(1, 10, length=10)
    @test 1:3.0:10 === @set step(r) = 3
    @test 1:0.5:10 === @set length(r) = 19
    @test -5:1.0:10 === @set first(r) = -5
    @test 1:1.0:15 === @set last(r) = 15

    r = Base.OneTo(10)
    @test 1:3:10 === @set step(r) = 3
    @test 1:0.5:10 === @set length(r) = 19
    @test -5:10 === @set first(r) = -5
    @test Base.OneTo(15) === @set last(r) = 15
end

@testitem "arrays" begin
    using OffsetArrays

    A = [1 2 3; 4 5 6]
    
    B = @set axes(A)[1] = 10:11
    @test parent(B) == A
    @test_broken parent(B) === A
    @test axes(B) == (10:11, 1:3)

    @test_throws Exception @set axes(A)[1] = 10:12

    @test A == @set axes(A)[1] = Base.OneTo(2)
    @test reshape(A, (2, 1, 3)) == @insert axes(A)[2] = Base.OneTo(1)
    B = @insert size(A)[2] = 1
    @test reshape(A, (2, 1, 3)) == B
    @test A == @delete size(B)[2]
    @test_throws Exception @set size(A)[1] = 1
    @test_throws Exception @insert size(A)[2] = 2

    @inferred set(A, @optic(axes(_)[1]), Base.OneTo(2))
    @inferred insert(A, @optic(axes(_)[2]), Base.OneTo(1))
    @inferred insert(A, @optic(size(_)[2]), 1)
    @inferred delete(B, @optic(size(_)[2]))

    B = @set vec(A) = 1:6
    @test B == [1 3 5; 2 4 6]

    B = @set reverse(vec(A)) = 1:6
    @test B == [6 4 2; 5 3 1]
end

@testitem "axiskeys" begin
    using AxisKeys

    A = KeyedArray([1 2 3; 4 5 6], x=[:a, :b], y=11:13)

    for B in (
        @set(axiskeys(A)[1] = [:y, :z]),
        @set(named_axiskeys(A).x = [:y, :z]),
        @set(A |> axiskeys(_, 1) = [:y, :z]),
        @set(A |> axiskeys(_, :x) = [:y, :z]),
    )
        @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
        @test named_axiskeys(B) == (x=[:y, :z], y=11:13)
    end

    for B in (
        @set(axiskeys(A)[2] = [:y, :z, :w]),
        @set(named_axiskeys(A).y = [:y, :z, :w]),
        @set(A |> axiskeys(_, 2) = [:y, :z, :w]),
        @set(A |> axiskeys(_, :y) = [:y, :z, :w]),
    )
        @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
        @test named_axiskeys(B) == (x=[:a, :b], y=[:y, :z, :w])
    end

    B = @set named_axiskeys(A) = (a=[1, 2], b=[3, 2, 1])
    @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
    @test named_axiskeys(B) == (a=[1, 2], b=[3, 2, 1])

    B = @set dimnames(A) = (:a, :b)
    @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
    @test named_axiskeys(B) == (a=[:a, :b], b=11:13)

    B = @set A.x = 10:11
    @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
    @test named_axiskeys(B) == (x=10:11, y=11:13)

    B = @replace named_axiskeys(A) |> (_.z = _.x)
    @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
    @test named_axiskeys(B) == (z=[:a, :b], y=11:13)

    B = @set AxisKeys.keyless_unname(A) = [6 5 4; 3 2 1]
    @test named_axiskeys(B) == named_axiskeys(A)
    @test AxisKeys.keyless_unname(B) == [6 5 4; 3 2 1]

    B = @set vec(A) = 1:6
    @test AxisKeys.keyless_unname(B) == [1 3 5; 2 4 6]
    @test named_axiskeys(B) == named_axiskeys(A)


    @test_throws ArgumentError @set axiskeys(A)[1] = 1:3
    @test_throws ArgumentError @set named_axiskeys(A).x = 1:3
    @test_throws Exception     @set axiskeys(A) = ()
    @test_throws ArgumentError @set named_axiskeys(A) = (;)
    @test_throws ArgumentError @set A.z = 10:11


    A = KeyedArray([1 2 3; 4 5 6], ([:a, :b], 11:13))

    B = @set axiskeys(A)[1] = [:y, :z]
    @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
    @test axiskeys(B) == ([:y, :z], 11:13)

    B = @set named_axiskeys(A) = (a=[1, 2], b=[3, 2, 1])
    @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
    @test named_axiskeys(B) == (a=[1, 2], b=[3, 2, 1])

    B = @set dimnames(A) = (:a, :b)
    @test AxisKeys.keyless_unname(A) === AxisKeys.keyless_unname(B)
    @test named_axiskeys(B) == (a=[:a, :b], b=11:13)

    # B = @set AxisKeys.keyless_unname(A) = [6 5 4; 3 2 1]
    # @test named_axiskeys(B) == named_axiskeys(A)
    # @test AxisKeys.keyless_unname(A) == [6 5 4; 3 2 1]

    B = @set vec(A) = 1:6
    @test AxisKeys.keyless_unname(B) == [1 3 5; 2 4 6]
    @test axiskeys(B) == axiskeys(A)
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
end

@testitem "other optics" begin
    using Dictionaries

    T = (4, 5, 6)
    @test (8, 10, 12) === @inferred modify(x -> 2x, T, Values())
    @test (5, 7, 9) === @inferred modify(((i, x),) -> i => i + x, T, Pairs())
    @test_throws AssertionError @modify(((i, x),) -> (i+1) => i + x, T |> Pairs())
    T = (a=4, b=5, c=6)
    @test (a=8, b=10, c=12) === @inferred modify(x -> 2x, T, Values())
    @test (aa=4, bb=5, cc=6) === modify(x -> Symbol(x, x), T, Keys())
    @test (a=(:a, 8), b=(:b, 10), c=(:c, 12)) === @inferred modify(((i, x),) -> i => (i, 2x), T, Pairs())
    A = [4, 5, 6]
    @test [8, 10, 12] == @inferred modify(x -> 2x, A, Values())
    @test [5, 7, 9] == @inferred modify(((i, x),) -> i => i + x, A, Pairs())
    D = Dict(4 => 5, 6 => 7)
    @test Dict(4 => 6, 6 => 8) == @inferred modify(x -> x+1, D, Values())
    @test Dict(5 => 5, 7 => 7) == @inferred modify(x -> x+1, D, Keys())
    @test Dict(8 => 9, 12 => 13) == @inferred modify(((i, x),) -> 2i => i + x, D, Pairs())
    D = dictionary([4 => 5, 6 => 7])
    @test dictionary([4 => 6, 6 => 8]) == @inferred modify(x -> x+1, D, Values())
    @test dictionary([5 => 5, 7 => 7]) == @inferred modify(x -> x+1, D, Keys())
    D = ArrayDictionary([4, 6], [5, 7])
    @test dictionary([4 => 6, 6 => 8]) == @inferred modify(x -> x+1, D, Values())
    @test dictionary([5 => 5, 7 => 7]) == @inferred modify(x -> x+1, D, Keys())
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

@testitem "intervals" begin
    using IntervalSets

    int = Interval{:open, :closed}(1, 5)
    @test Interval{:open, :closed}(1, 10) === @set int.right = 10
    @test Interval{:open, :closed}(10.0, 11.0) === @set endpoints(int) = (10.0, 11.0)
    @test Interval{:open, :closed}(-2, 5) === @set leftendpoint(int) = -2
    @test Interval{:open, :closed}(1, 2) === @set rightendpoint(int) = 2
    @test Interval{:closed, :closed}(1, 5) === @set first(closedendpoints(int)) = true

    @test 1 === @set 2 |> mod(_, 0..3) = 1
    @test 0 === @set 2 |> mod(_, 0..3) = 0
    @test 3 === @set 2 |> mod(_, 0..3) = 3
    @test 31 === @set 32 |> mod(_, 0..3) = 1
    @test 1 === @set 2 |> mod(_, 20..23) = 21
    @test 0 === @set 2 |> mod(_, 20..23) = 20
    @test 3 === @set 2 |> mod(_, 20..23) = 23
    @test 31 === @set 32 |> mod(_, 20..23) = 21
end


@testitem "_" begin
    import CompatHelperLocal as CHL
    CHL.@check()

    using Aqua
    Aqua.test_all(AccessorsExtra, piracy=false)
end
