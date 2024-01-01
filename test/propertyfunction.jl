
@testitem "basic" begin
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

    o = @o round(Int, _.a.b + _.a.c + _.b.d + _.b.d)
    @test needed_properties(o) == (:a, :b)
    @test o((a=(b=1, c=2), b=(d=3,))) == 9

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

@testitem "structarrays" begin
    using StructArrays
    using FlexiMaps

    A = StructArray(
        x=mapview(_ -> error("Shouldn't happen"), 1:100),
        y=10:10:1000
    )
    @test A.x === @inferred map((@o _.x), A)
    @test A.y === @inferred map((@o _.y), A)
    @test 11:10:1001 == @inferred map((@o _.y + 1), A)
    @test_throws "Shouldn't happen" @inferred map((@o _.x + 1), A)

    B = StructArray(
        xy=A,
        z=StructArray{ComplexF64}(
            re=mapview(_ -> error("Shouldn't happen"), 1:100),
            im=0.01:0.01:1.0,
        )
    )
    @test B.xy.y === @inferred map((@o _.xy.y), B)
    @test 11:10:1001 == @inferred map((@o _.xy.y + 1), B)
    @test_throws "Shouldn't happen" @inferred map((@o _.xy.x + 1), B)

    @test 20:20:2000 == @inferred map((@o _.xy.y + _.xy.y), B)
    @test 10.01:10.01:1001.0 == @inferred map((@o _.xy.y + _.z.im), B)
end
