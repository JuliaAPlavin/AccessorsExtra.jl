@testitem "basic" begin
    using AccessorsExtra: propspec, Placeholder as P
    o = @o _.a + 1
    @test propspec(o) == (a=P(),)
    @test o((a=2,)) == 3

    @test propspec(@o _ + 1) == P()
    @test propspec(@o _[1] + 1) == P()

    o = @o _.a + _.b.c
    @test propspec(o) == (a=P(), b=(c=P(),))
    @test_broken propspec(o) == propspec(typeof(o))
    @test o((a=2, b=(c=3,))) == 5

    o = @o exp10(_.a + _.b.c)
    @test propspec(o) == (a=P(), b=(c=P(),))
    @test o((a=2, b=(c=3,))) == 10^5

    o = @o round(Int, _.a + _.b.c)
    @test propspec(o) == (a=P(), b=(c=P(),))
    @test o((a=2.6, b=(c=3,))) == 6

    o = @o round(Int, _.a.b + _.a.c + _.b.d + _.b.d)
    @test propspec(o) == (a=(b=P(), c=P()), b=(d=P(),))
    @test o((a=(b=1, c=2), b=(d=3,))) == 9

    macro mym_str(expr)
        expr
    end
    begin
        o = @o _.a + _.b + parse(Int, mym"3")
        @test propspec(o) == (a=P(), b=P())
        @test o((a=1, b=2)) == 6
    end

    o = @o (_.xy.y, _.z.im)
    @test o((xy=(x=1, y=2), z=ComplexF64(0, 3))) == (2, 3)
    o = @o (a=_.xy.y+1, b=_.z.im + _.xy.y)
    @test o((xy=(x=1, y=2), z=ComplexF64(0, 3))) == (a=3, b=5)
    o = @o (;a=_.xy.y+1, b=_.z.im + _.xy.y)
    @test o((xy=(x=1, y=2), z=ComplexF64(0, 3))) == (a=3, b=5)

    @test (!@o _.a)((a=true,)) == false
    @test (!@o _.a > _.b)((a=1, b=2)) == true

    o = @o _ + _ + 1
    @test propspec(o) == P()
    @test o(2) == 5

    o = @o _.a + _[2] + 1
    @test propspec(o) == P()
    @test o((a=10, b=100)) == 111

    o = @o _.a .+ _.b
    @test o((a=[1,2], b=[3,4])) == [4, 6]

    o = @o (a=_.xy.y + 1, b=_.xy.z + _.z.im)
    @test propspec(o) == (xy=(y=P(), z=P()), z=(im=P(),))

    o = @o (a=_.xy.y + 1, b=_.xy.z + _.z.im, c=_.z)
    @test propspec(o) == (xy=(y=P(), z=P()), z=P())

    o = @o 0 < _.xy.y < 100
    @test propspec(o) == (xy=(y=P(),),)

    o = @o 0 < _.xy.y && _.z.im > _.xy.z
    @test propspec(o) == (xy=(y=P(), z=P()), z=(im=P(),))

    o = @o atan(_.a...)
    @test propspec(o) == (a=P(),)

    o = @o _.a .+ 1
    @test propspec(o) == (a=P(),)
end

@testitem "maybe" begin
    o = @o _.a + _.b.c
    @test oget(nothing, o, nothing) === nothing
    @test oget((a=2, b=(c=3,)), o, nothing) == 5
    @test oget((a=nothing, b=(c=3,)), o, nothing) === nothing
    @test oget((a=2, b=(c=nothing,)), o, nothing) === nothing

    o = @o (_.a, _.b)
    @test oget((a=1, b=(c=nothing,)), o, nothing) === (1, (c=nothing,))
end

@testitem "no ambiguities" begin
    # @test map((@o isodd(_.a)), ((a=1,), (a=2,), (a=3,)))  # difficult to avoid ambiguities for tuples...
    @test map((@o isodd(_.a)), [(a=1,), (a=2,), (a=3,)]) == [true, false, true]

    @test filter((@o isodd(_.a)), ((a=1,), (a=2,), (a=3,))) == ((a=1,), (a=3,))
    @test filter((@o isodd(_.a)), [(a=1,), (a=2,), (a=3,)]) == [(a=1,), (a=3,)]

    @test findall((@o isodd(_.a)), ((a=1,), (a=2,), (a=3,))) == [1, 3]
    @test findall((@o isodd(_.a)), [(a=1,), (a=2,), (a=3,)]) == [1, 3]
end

@testitem "structarrays" begin
    using StructArrays
    using FlexiMaps
    using FlexiGroups
    using Skipper: filterview

    A = StructArray(
        x=Vector{Any}(undef, 100),
        y=10:10:1000
    )
    @test A.x === @inferred mapview((@o _.x), A)
    @test A.y === @inferred mapview((@o _.y), A)
    @test A.y == @inferred map((@o _.y), A)
    @test 11:10:1001 == @inferred mapview((@o _.y + 1), A)
    @test 11:10:1001 == @inferred map((@o _.y + 1), A)
    @test_throws UndefRefError @inferred map((@o _.x + 1), A)

    B = StructArray(
        xy=A,
        z=StructArray{ComplexF64}(
            re=Vector{Any}(undef, 100),
            im=0.01:0.01:1.0,
        )
    )
    @test B.xy.y === @inferred mapview((@o _.xy.y), B)
    @test 11:10:1001 == @inferred map((@o _.xy.y + 1), B)
    @test_throws UndefRefError @inferred map((@o _.xy.x + 1), B)

    @test 2:2:200 == @inferred map((@o _.xy.y + _.xy.y), [(xy=(y=i,),) for i in 1:100])
    @test 20:20:2000 == @inferred map((@o _.xy.y + _.xy.y), B)
    @test 10.01:10.01:1001.0 == @inferred map((@o _.xy.y + _.z.im), B)

    @test (@inferred map((@o (a=_.xy.y+1, b=_.z.im + _.xy.y, c=(; _.xy.y,))), B); true)
    C = map((@o (a=_.xy.y+1, b=_.z.im + _.xy.y, c=(; _.xy.y,))), B)
    @test C[5] == (a = 51, b = 50.05, c = (y=50,))
    @test C.a == 11:10:1001
    @test C.c.y == 10:10:1000

    C = mapinsert(B, x=@o _.xy.y + 1)
    @test C.xy === B.xy
    @test C.x == 11:10:1001

    @test mapview((@o _.xy.y > _.z.im), B) == fill(true, 100)

    @test groupview((@o _.xy.y), B) |> length == 100
    @test groupview((@o _.xy.y > _.z.im), B)[true].xy.y == 10:10:1000

    C = @inferred mapview((@o (a=_.xy.y+1, b=_.z.im + _.xy.y, c=(; _.xy.y,))), B)
    @test C[5] == (a = 51, b = 50.05, c = (y=50,))

    @test findall((@o _.xy.y > 100), B) == 11:100
    @test findall((@o _.xy.y > _.z.im + 100), B) == 11:100
    @test_broken filter((@o _.xy.y > 100), B).xy.y == 110:10:1000
    @test_broken filter((@o _.xy.y > _.z.im + 100), B).xy.y == 110:10:1000
    @test filterview((@o _.xy.y > _.z.im + 100), B).xy.y == 110:10:1000
    @test sortperm(B, by=(@o _.xy.y ≤ 100)) == [11:100; 1:10]
    @test sortperm(B, by=!(@o _.xy.y > _.z.im + 100)) == [11:100; 1:10]
    # test that it throws on actual item permutation, not comparison:
    # @test_throws "setindex! not defined for StepRange" sort!(B, by=(@o _.xy.y ≤ 100))
    # @test_throws "setindex! not defined for StepRange" sort!(B, by=!(@o _.xy.y > _.z.im + 100))

    B = StructArray(
        xy=repeat([1,2,3], outer=4),
        z=StructArray{ComplexF64}(
            re=collect(1:12),
            im=collect(0.01:0.01:0.12),
        )
    )
    o = @o _.xy
    @test sortperm(B, by=o) == sortperm(B, by=x->o(x))
    @test sort(B, by=o) == sort(B, by=x->o(x))
    @test sort!(deepcopy(B), by=o) == sort!(deepcopy(B), by=x->o(x))
end

@testitem "structarrays - containeroptic" begin
    # XXX: see structarrays section in concatoptic.jl
    using StructArrays
    using FlexiMaps
    using FlexiGroups

    A = StructArray(
        x=Vector{Any}(undef, 100),
        y=10:10:1000
    )
    @test A.x === @inferred mapview((@o _.x), A)
    @test A.y === @inferred mapview((@o _.y), A)
    @test A.y == @inferred map((@o _.y), A)
    @test 11:10:1001 == @inferred mapview((@o _.y + 1), A)
    @test 11:10:1001 == @inferred map((@o _.y + 1), A)
    @test_throws UndefRefError @inferred map((@o _.x + 1), A)

    B = StructArray(
        xy=A,
        z=StructArray{ComplexF64}(
            re=Vector{Any}(undef, 100),
            im=0.01:0.01:1.0,
        )
    )
    @test B.xy.y === @inferred mapview((@o _.xy.y), B)
    @test 11:10:1001 == @inferred map((@o _.xy.y + 1), B)
    @test_throws UndefRefError @inferred map((@o _.xy.x + 1), B)

    @test 20:20:2000 == @inferred map((@o _.xy.y + _.xy.y), B)
    @test 10.01:10.01:1001.0 == @inferred map((@o _.xy.y + _.z.im), B)

    C = @inferred map((@o (a=_.xy.y+1, b=_.z.im + _.xy.y, c=(;_.xy.y))), B)
    @test C[5] == (a = 51, b = 50.05, c = (y=50,))
    @test C.a == 11:10:1001
    @test C.c.y == 10:10:1000

    C = mapinsert(B, x=@o _.xy.y + 1)
    @test C.xy === B.xy
    @test C.x == 11:10:1001

    @test mapview((@o _.xy.y > _.z.im), B) == fill(true, 100)

    @test groupview((@o _.xy.y), B) |> length == 100
    @test groupview((@o _.xy.y > _.z.im), B)[true].xy.y == 10:10:1000

    C = @inferred mapview((@o (a=_.xy.y+1, b=_.z.im + _.xy.y, c=(y=_.xy.y,))), B)
    @test C[5] == (a = 51, b = 50.05, c = (y=50,))
end

@testitem "dictarrays" begin
    using StructArrays
    using DictArrays
    using FlexiMaps

    A = DictArray(
        x=Vector{Any}(undef, 100),
        y=10:10:1000
    )
    @test A.x === mapview((@o _.x), A)
    @test A.y === mapview((@o _.y), A)
    @test A.y == map((@o _.y), A)
    @test 11:10:1001 == map((@o _.y + 1), A)
    @test 20:20:2000 == map((@o _.y + _.y), A)
    @test_throws UndefRefError map((@o _.x + 1), A)

    B = StructArray(
        xy=A,
        z=DictArray(
            re=Vector{Any}(undef, 100),
            im=0.01:0.01:1.0,
            a=StructArray(
                u=Vector{Any}(undef, 100),
                v=1:100,
            )
        )
    )
    @test B.xy.y === mapview((@o _.xy.y), B)
    @test 11:10:1001 == map((@o _.xy.y + 1), B)
    @test_throws UndefRefError map((@o _.xy.x + 1), B)

    @test 20:20:2000 == map((@o _.xy.y + _.xy.y), B)
    @test 10.01:10.01:1001.0 == map((@o _.xy.y + _.z.im), B)

    C = map((@o (a=_.xy.y+1, b=_.z.im + _.xy.y, c=(; _.z.a.v,))), B)
    @test C isa StructArray
    @test C.c isa StructArray
    @test C[5] == (a = 51, b = 50.05, c = (v=5,))
    @test C.a == 11:10:1001
    @test C.c.v == 1:100
end
