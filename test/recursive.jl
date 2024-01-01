@testitem "basic" begin
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

    m = (a=1, b=2+3im)
    or = RecursiveOfType(Real)
    @test getall(m, or) == (1, 2, 3)
    @test modify(x->x+10, m, or) == (a=11, b=12+13im)
    @test setall(m, or, (10, 20, 30)) == (a=10, b=20+30im)

    end
end

@testitem "walk types" begin
    AccessorsExtra.@allinferred set modify getall setall begin

    m = (a=1, b=2+3im)
    or = RecursiveOfType(Number)
    @test or === RecursiveOfType(Number, order=nothing)
    @test_throws ErrorException RecursiveOfType(Number, order=:xxx)

    @test getall(m, or) == (1, 2+3im)
    @test modify(x->x+10, m, or) == (a=11, b=12+3im)
    @test setall(m, or, (10, 20)) == (a=10, b=20)

    or = RecursiveOfType(Number, order=:pre)
    @test getall(m, or) == (1, 2+3im, 2, 3)
    @test modify(x->x^2, m, or) == (a=1, b=25+144im)
    @test_throws "setall not supported with order = pre" setall(m, or, (10, 20))

    or = RecursiveOfType(Number, order=:post)
    @test getall(m, or) == (1, 2, 3, 2+3im)
    @test modify(x->x^2, m, or) == (a=1, b=-65+72im)
    @test_throws "setall not supported with order = post" setall(m, or, (10, 20))

    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx")))
    or = RecursiveOfType(NamedTuple, order=:post)
    @test getall(m, or) === ((c = 1, d = "2"), (c = 3, d = "xxx"), m)
    @test modify(Dict ∘ pairs, m, or) == Dict(:a => 1, :bs => (Dict(:d => "2", :c => 1), Dict(:d => "xxx", :c => 3)))

    m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx", e=((;),))))
    @test getall(m, or) === ((c = 1, d = "2"), (;), (c = 3, d = "xxx", e = ((;),)), (a = 1, bs = ((c = 1, d = "2"), (c = 3, d = "xxx", e = ((;),)))))

    end
end

# keyed:
@testitem "modify-many" begin
    AccessorsExtra.@allinferred modify begin

    @test modify(+, (a=1, b=2), RecursiveOfType(Number), (a=10, b=20)) === (a=11, b=22)
    @test modify(+, (a=1, b="", c=(d=2, e=3)), RecursiveOfType(Number), (a=10, b=20, c=(d=30, e=40))) === (a=11, b="", c=(d=32, e=43))
    @test modify(+, (a=1, b=("", (d=2, e=3))), RecursiveOfType(Number), (a=10, b=(20, (d=30, e=40)))) === (a=11, b=("", (d=32, e=43)))
    @test modify(+, (a=1, b=[(d=2, e=3)]), RecursiveOfType(Number), (a=10, b=[(d=30, e=40)])) == (a=11, b=[(d=32, e=43)])
    
    @test modify(+, (a=1, b="", c=(re=2, im=3)), RecursiveOfType(Real), (a=10, b=20, c=30+40im)) === (a=11, b="", c=(re=32, im=43))
    @test modify(+, (a=1, b="", c=2+3im), RecursiveOfType(Real), (a=10, b=20, c=30+40im)) === (a=11, b="", c=32+43im)
    @test modify(+, (a=1, b="", c=2+3im), RecursiveOfType(Real), (a=10, b=20, c=(re=30, im=40))) === (a=11, b="", c=32+43im)

    @test modify(+, (a=1, b="", c=2+3im), RecursiveOfType(Number), (a=10, b=20, c=30+40im)) === (a=11, b="", c=32+43im)
    @test modify(+, (a=1, b="", c=2+3im), RecursiveOfType(Number, order=:pre), (a=10, b=20, c=30+40im)) === (a=11, b="", c=62+83im)

    end
end

# @testitem "keyed" begin
    # or = keyed(RecursiveOfType(Number))
    # m = (a=1, bs=((c=1, d="2"), (c=3, d="xxx")))
    # @test getall(m, or) == (1, 1, 3)
# end
