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

    @test (@optics _.a _.b) ++ (@optics _.c _.d) === @optics _.a _.b _.c _.d
    @test (@optics _.a _.b) ++ (@o _.c) === @optics _.a _.b _.c
    @test (@optics _.a _.b) ++ concat() ++ (@o _.c) === @optics _.a _.b _.c

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

    @test_broken eval(:(@optic₊ (;_.a)))
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
