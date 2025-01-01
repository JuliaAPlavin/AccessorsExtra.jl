@testitem "get() as optic" begin
    AccessorsExtra.@allinferred o set modify begin
    @testset for o in ((@o get(_, :a, 0)), (@o get(() -> 0, _, :a)))
        @test o((a=1, b=2)) == 1
        @test o((c=1, b=2)) == 0
        @test set(Dict(:a=>1, :b=>2), o, 10) == Dict(:a=>10, :b=>2)
        @test set(Dict(:c=>1, :b=>2), o, 10) == Dict(:c=>1, :b=>2, :a=>10)
        @test modify(x->x+1, Dict(:a=>1, :b=>2), o) == Dict(:a=>2, :b=>2)
        @test modify(x->x+1, Dict(:c=>1, :b=>2), o) == Dict(:a=>1, :c=>1, :b=>2)
    end
    end
end

@testitem "maybe" begin
    using Dates

    AccessorsExtra.@allinferred modify set getall setall delete begin
    # @test set(1, something, 2) == 2
    # @test set(Some(1), something, 2) == Some(2)

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

    @test delete((a=[1, 2],), o) == (a=[1],)
    @test delete((a=[1],), o) == (a=[1],)
    @test_throws Exception delete((;), o)

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
        @test getall((a=(;),), o) == (nothing,)
        @test getall((;), o) == (nothing,)
        @test getall(nothing, o) == (nothing,)
        @test setall((a=(b=1,),), o, (5,)) == (a=(b=5,),)
        @test setall((a=(;),), o, (123,)) == (a=(;),)
        @test setall((;), o, (123,)) == (;)
        @test setall(nothing, o, (123,)) == nothing
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

    o = maybe(length)
    @test o([1, 2, 3]) == 3
    @test o([]) == 0
    @test o((i for i in 1:10 if i % 2 == 1)) === nothing
    @test_broken o(:abc) === nothing
    @test o(nothing) === nothing

    o = maybe(@o parse(Int, _))
    @test o("1") == 1
    @test o("a") === nothing
    @test o(nothing) === nothing
    @test modify(x -> x+1, "1", o) == "2"
    @test modify(x -> x+1, "a", o) == "a"
    @test set("1", o, 2) == "2"
    @test_broken set("a", o, 2) == "2"

    o = maybe(@o parse(Date, _, dateformat"Y/m/d"))
    @test o("2020/02/03") == Date(2020, 2, 3)
    @test o("2020-02-03") === nothing
    @test o(nothing) === nothing
    @test_broken modify(x -> x+Day(1), "2020/02/03", o) == "2020/02/04"
    @test modify(x -> x+Day(1), "2020-02-03", o) == "2020-02-03"
    @test_broken set("2020/02/03", o, Date(1234, 5, 6)) == "1234/05/06"
    @test_broken set("2020-02-03", o, Date(1234, 5, 6)) == "1234/05/06"

    o = maybe(@o _.a) ∘ Elements()
    @test getall(((a=1,), (b=2,)), o) === (1, nothing)
    @test getall(((b=2,),), o) === (nothing,)
    @test getall(((),), o) === (nothing,)
    @test modify(x -> x+1, ((a=1,), (b=2,)), o) === ((a=2,), (b=2,))
    @test modify(x -> nothing, ((a=1,), (b=2,)), o) === ((;), (b=2,))
    @test set(((a=1,), (b=2,)), o, 10) === ((a=10,), (b=2,))
    @test set(((a=1,), (b=2,)), o, nothing) === ((;), (b=2,))
    @test setall(((a=1,), (b=2,)), o, (10, 123)) === ((a=10,), (b=2,))
    @test_throws "tried to assign 0 elements to 2 destinations" setall(((a=1,), (b=2,)), o, ()) === ((a=10,), (b=2,))
    @test_throws "tried to assign 1 elements to 2 destinations" setall(((a=1,), (b=2,)), o, (10,)) === ((a=10,), (b=2,))

    # specify default value in maybe() - semantic not totally clear...
    # also see "get(...) as optic"
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

    @test maybe(first)((i for i in 1:3)) == 1
    @test maybe(first)((i for i in 1:0)) == nothing
    @test maybe(last)((i for i in 1:3)) == 3
    @test maybe(last)((i for i in 1:0)) == nothing
end

@testitem "@maybe" begin
    f = x -> 2*x
    @test (@maybe _.a) === maybe(@o _.a)
    @test (@maybe _.a[∗][2]) === maybe(@o _.a[∗][2])
    @test (@maybe exp(_.a[∗][2])) === maybe(@o exp(_.a[∗][2]))
    @test (@maybe _.a 10) === maybe(@o _.a; default=10)
    @test (@maybe f(_)) === maybe(f)
end

@testitem "oget" begin
    AccessorsExtra.@allinferred oget begin
        o = @o _.a[2]
        @test oget((a=[1, 2, 3],), o, 123) == 2
        @test oget((;), o, 123) == 123
        @test oget((;), o) == nothing
        @test oget(Returns(123), (a=[1, 2, 3],), o) == 2
        @test oget(Returns(123), (;), o) == 123
    end
    @test oget((a=[1, 2, 3],), o) == 2
    @test oget((a=[1],), o) == nothing
end

@testitem "@oget" begin
    f = x -> 2*x
    x = (a=[1, 2],)
    @test (@oget x.a[2] 123) === 2
    @test (@oget x.a[2] error()) === 2
    @test (@oget x.a[3] 123) === 123
    @test (@oget x.a[2]) === 2
    @test (@oget x.a[3]) === nothing
    @test (@oget f(x.a[2]) 123) === 4

    @test (@oget x.a[2] x.a[3]) === 2
    @test (@oget x.a[3] x.a[2]) === 2
    @test (@oget 123) === 123
    @test (@oget 123 456) === 123
    @test (@oget 123 x.a[2]) === 123

    @test (@oget x.a[3] x.a[2] 123) === 2
    @test (@oget x.a[3] x.a[2] error()) === 2
    @test (@oget x.a[2] error() 123) === 2
    @test_throws ErrorException (@oget x.a[3] error() 123)
    @test (@oget x.a[3] x.a[4] 123) === 123
end

@testitem "osomething" begin
    o = osomething(@o(_.a), @o(_.b))
    @test o((a=1, b=2)) == 1
    @test o((c=1, b=2)) == 2
    @test_throws "no optic" o((c=1,))
    @test set((a=1, b=2), o, 10) == (a=10, b=2)
    @test set((c=1, b=2), o, 10) == (c=1, b=10)
    @test_throws "no optic" set((c=1,), o, 10)

    o = osomething(@o(_.a), @o(error(_.b)))
    @test o((a=1, b=2)) == 1
    @test_throws ErrorException o((c=1, b=2))
    @test set((a=1, b=2), o, 10) == (a=10, b=2)
    @test_throws "error" set((c=1, b=2), o, 10)
end

@testitem "@osomething" begin
    f = x -> 2*x
    @test osomething(@o(_.a)) === @osomething _.a
    @test osomething(@o(_.a), @o(_.b)) === @osomething _.a _.b
    @test osomething(@o(_.a), @o(f(_.b))) === @osomething _.a f(_.b)
    @test osomething(@o(_.a), @o NaN) === @osomething _.a NaN
    @test osomething(@o(_.a), @o 0/0) === @osomething _.a 0/0
end
