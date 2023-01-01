using AccessorsExtra
using Test
using StructArrays
using SplitApplyCombine
using AxisKeys
using Distributions
using Dictionaries
using InverseFunctions


@testset "structarrays" begin
    s = StructArray(a=[1, 2, 3])
    @test @insert(StructArrays.components(s).b = 10:12) == [(a=1, b=10), (a=2, b=11), (a=3, b=12)]
    @test setproperties(s, a=10:12) == StructArray(a=10:12)
    @test_throws ArgumentError setproperties(s, b=10:12)
    @test @set(s.a = 10:12) == StructArray(a=10:12)
    @test @insert(s.b = 10:12) == [(a=1, b=10), (a=2, b=11), (a=3, b=12)]
    @test @delete(@insert(s.b = 10:12).a) == StructArray(b=10:12)
    @test @delete(s.a) == NamedTuple{(), Tuple{}}[]

    s = StructArray([(a=(x=1, y=:abc),), (a=(x=2, y=:def),)]; unwrap=T -> T <: NamedTuple)
    @test @set(s.a = 10:12) == StructArray(a=10:12)
    @test @set(s.a.x = 10:11) == [(a=(x=10, y=:abc),), (a=(x=11, y=:def),)]
    @test @insert(s.b = 10:11) == [(a=(x=1, y=:abc), b=10), (a=(x=2, y=:def), b=11)]
    @test @insert(s.a.z = 10:11) == [(a=(x=1, y=:abc, z=10),), (a=(x=2, y=:def, z=11),)]
    @test @delete(s.a.y) == [(a=(x=1,),), (a=(x=2,),)]
end

@testset "mapview" begin
    X = [(a=1, b=2), (a=3, b=4)]
    Y = mapview(@optic(_.b), X)
    @test Y == [2, 4]
    Y[2] = 100
    @test Y == [2, 100]
    @test X == [(a=1, b=2), (a=3, b=100)]
end

@testset "getfield" begin
    t = (x=1, y=2)
    @test set(t, @optic(getfield(_, :x)), :hello) === (x=:hello, y=2)
    @test_throws Exception set(t, @optic(getfield(_, :z)), 3)
end

@testset "view" begin
    A = [1, 2, (a=3, b=4)]
    opt = @optic _ |> ViewLens(3) |> _.a
    @test opt(A) == 3
    @test set(A, opt, 10) === A == [1, 2, (a=10, b=4)]
    @test set(A, ViewLens((1:2,)), [-2, -3]) === A == [-2, -3, (a=10, b=4)]
    @test @modify(x -> 2x, A |> ViewLens((1:2,))) === A == [-4, -6, (a=10, b=4)]
    Accessors.test_getset_laws(opt, A, "a", :b)
    Accessors.test_getset_laws(@optic(_ |> ViewLens((1:2,))), A, [5, 6], [7, 8])
end

@testset "axes" begin
    A = [1 2 3; 4 5 6]
    
    B = @set axes(A)[1] = 10:11
    @test parent(B) == A
    @test axes(B) == (10:11, 1:3)

    @test_throws Exception @set axes(A)[1] = 10:12
end

@testset "axiskeys" begin
    A = KeyedArray([1 2 3; 4 5 6], x=[:a, :b], y=11:13)

    B = @set axiskeys(A)[1] = [:y, :z]
    @test @set(A |> axiskeys(_, 1) = [:y, :z]) == B
    @test AxisKeys.keyless_unname(A) == AxisKeys.keyless_unname(B)
    @test dimnames(B) == (:x, :y)
    @test named_axiskeys(B) == (x=[:y, :z], y=11:13)

    B = @set named_axiskeys(A).y = [:y, :z, :w]
    @test @set(A |> named_axiskeys(_, :y) = [:y, :z, :w]) == B
    @test AxisKeys.keyless_unname(A) == AxisKeys.keyless_unname(B)
    @test dimnames(B) == (:x, :y)
    @test named_axiskeys(B) == (x=[:a, :b], y=[:y, :z, :w])

    B = @set named_axiskeys(A) = (a=[1, 2], b=[3, 2, 1])
    @test AxisKeys.keyless_unname(A) == AxisKeys.keyless_unname(B)
    @test dimnames(B) == (:a, :b)
    @test named_axiskeys(B) == (a=[1, 2], b=[3, 2, 1])

    B = @set dimnames(A) = (:a, :b)
    @test AxisKeys.keyless_unname(A) == AxisKeys.keyless_unname(B)
    @test dimnames(B) == (:a, :b)
    @test named_axiskeys(B) == (a=[:a, :b], b=11:13)

    B = @set A.x = 10:11
    @test AxisKeys.keyless_unname(A) == AxisKeys.keyless_unname(B)
    @test dimnames(B) == (:x, :y)
    @test named_axiskeys(B) == (x=10:11, y=11:13)


    @test_throws ArgumentError @set axiskeys(A)[1] = 1:3
    @test_throws ArgumentError @set named_axiskeys(A).x = 1:3
    @test_throws Exception     @set axiskeys(A) = ()
    @test_throws ArgumentError @set named_axiskeys(A) = (;)
    @test_throws ArgumentError @set A.z = 10:11


    A = KeyedArray([1 2 3; 4 5 6], ([:a, :b], 11:13))

    B = @set axiskeys(A)[1] = [:y, :z]
    @test AxisKeys.keyless_unname(A) == AxisKeys.keyless_unname(B)
    @test dimnames(B) == (:_, :_)
    @test axiskeys(B) == ([:y, :z], 11:13)

    B = @set named_axiskeys(A) = (a=[1, 2], b=[3, 2, 1])
    @test AxisKeys.keyless_unname(A) == AxisKeys.keyless_unname(B)
    @test dimnames(B) == (:a, :b)
    @test named_axiskeys(B) == (a=[1, 2], b=[3, 2, 1])

    B = @set dimnames(A) = (:a, :b)
    @test AxisKeys.keyless_unname(A) == AxisKeys.keyless_unname(B)
    @test dimnames(B) == (:a, :b)
    @test named_axiskeys(B) == (a=[:a, :b], b=11:13)
end

@testset "inverses" begin
    InverseFunctions.test_inverse(Base.Fix1(getindex, [4, 5, 6]), 2)
    InverseFunctions.test_inverse(Base.Fix1(getindex, Dict(2 => 123, 3 => 456)), 2)

    d = Normal(2, 5)
    InverseFunctions.test_inverse(@optic(cdf(d, _)), 2)
    InverseFunctions.test_inverse(@optic(quantile(d, _)), 0.1)
end

@testset "other optics" begin
    T = (4, 5, 6)
    @test @modify(x -> 2x, T |> Values()) === (8, 10, 12)
    T = (a=4, b=5, c=6)
    @test @modify(x -> 2x, T |> Values()) === (a=8, b=10, c=12)
    @test @modify(x -> Symbol(x, x), T |> Keys()) === (aa=4, bb=5, cc=6)
    A = [4, 5, 6]
    @test @modify(x -> 2x, A |> Values()) == [8, 10, 12]
    D = Dict(4 => 5, 6 => 7)
    @test @modify(x -> x+1, D |> Values()) == Dict(4 => 6, 6 => 8)
    @test @modify(x -> x+1, D |> Keys()) == Dict(5 => 5, 7 => 7)
    D = dictionary([4 => 5, 6 => 7])
    @test @modify(x -> x+1, D |> Values()) == dictionary([4 => 6, 6 => 8])
    @test @modify(x -> x+1, D |> Keys()) == dictionary([5 => 5, 7 => 7])
    D = ArrayDictionary([4, 6], [5, 7])
    @test @modify(x -> x+1, D |> Values()) == dictionary([4 => 6, 6 => 8])
    @test @modify(x -> x+1, D |> Keys()) == dictionary([5 => 5, 7 => 7])
end


import CompatHelperLocal as CHL
CHL.@check()

using Aqua
Aqua.test_all(AccessorsExtra)
