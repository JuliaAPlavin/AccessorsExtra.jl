@testitem "replace" begin
    nt = (a=1, b=:x)
    AccessorsExtra.@allinferred _replace begin
        @test AccessorsExtra._replace(nt, @o(_.a) => @o(_.c)) === (c=1, b=:x)
        @test AccessorsExtra._replace(nt, (@o(_.a) => @o(_.c)) ∘ identity) === (c=1, b=:x)
    end
    @test @replace(nt.c = nt.a) === (c=1, b=:x)
    @test @replace(nt.c = _.a) === (c=1, b=:x)
    @test @replace(_.c = nt.a) === (c=1, b=:x)
    @test_broken @eval @replace(nt |> (_.c = _.a)) === (c=1, b=:x)

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

@testitem "getall, setall" begin
    obj = (a=1, b=(2, 3))
    @test (@getall obj.b[∗]) === (2, 3)
    @test (@getall obj[∗][∗]) === (1, 2, 3)
    @test (@setall obj[∗] = (5, "6")) === (a=5, b="6")
    @test (@setall obj |> RecursiveOfType(Int) = (5, 6, 7)) === (a=5, b=(6, 7))
end
