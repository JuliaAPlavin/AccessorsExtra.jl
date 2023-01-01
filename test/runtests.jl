using AccessorsExtra
using Test
using StructArrays
using SplitApplyCombine


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


import CompatHelperLocal as CHL
CHL.@check()
