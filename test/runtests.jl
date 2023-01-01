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
end

@testset "mapview" begin
    X = [(a=1, b=2), (a=3, b=4)]
    Y = mapview(@optic(_.b), X)
    @test Y == [2, 4]
    Y[2] = 100
    @test Y == [2, 100]
    @test X == [(a=1, b=2), (a=3, b=100)]
end


import CompatHelperLocal as CHL
CHL.@check()
