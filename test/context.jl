@testitem "context" begin
    AccessorsExtra.@allinferred modify begin
    obj = ((a='a',), (a='b',), (a='c',))
    o = keyed(Elements()) ⨟ @o(_.a)
    @test modify(((i, v),) -> i => v, obj, o) == ((a=1=>'a',), (a=2=>'b',), (a=3=>'c',))
    o = keyed(Elements()) ⨟ @o(_.a) ⨟ @o(convert(Int, _) + 1)
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((1, 98), (2, 99), (3, 100))
    @test modify(((i, v),) -> i + v, obj, o) == ((a='b',), (a='d',), (a='f',))
    o = Elements() ⨟ keyed(Elements())
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((:a, 'a'), (:a, 'b'), (:a, 'c'))
    @test modify(((i, v),) -> v, obj, o) == obj
    o = Elements() ⨟ keyed(Properties())
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((:a, 'a'), (:a, 'b'), (:a, 'c'))
    @test modify(((i, v),) -> v, obj, o) == obj

    o = enumerated(Elements()) ⨟ Elements()
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == ((1, 'a'), (2, 'b'), (3, 'c'))
    @test modify(((i, v),) -> v, obj, o) == obj
    o = enumerated(Elements() ⨟ Properties())
    @test_broken map(x -> (x.ctx, x.v), getall(obj, o)) == ((1, 'a'), (2, 'b'), (3, 'c'))
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == [(1, 'a'), (2, 'b'), (3, 'c')]
    @test modify(((i, v),) -> v, obj, o) == obj
    o = Elements() ⨟ enumerated(Properties())
    @test_broken map(x -> (x.ctx, x.v), getall(obj, o)) == ((1, 'a'), (1, 'b'), (1, 'c'))
    @test map(x -> (x.ctx, x.v), getall(obj, o)) == [(1, 'a'), (1, 'b'), (1, 'c')]
    @test modify(((i, v),) -> v, obj, o) == obj
    end

    o = @o(_.b) ⨟ keyed(Elements()) ⨟ @o(_.a)
    @test modify(((i, v),) -> i => v, (a=1, b=((a='a',), (a='b',), (a='c',))), o) == (a=1, b=((a=1=>'a',), (a=2=>'b',), (a=3=>'c',)))
    @test modify(((i, v),) -> i => v, (a=1, b=[(a='a',), (a='b',), (a='c',)]), o) == (a=1, b=[(a=1=>'a',), (a=2=>'b',), (a=3=>'c',)])
    @test modify(
        wix -> wix.ctx => wix.v,
        (a=1, b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        keyed(@o(_.a)) ++ keyed(@o(_.b)) ⨟ @o(_[∗].a)
    ) == (a=:a=>1, b=(x=(a=:b=>'a',), y=(a=:b=>'b',), z=(a=:b=>'c',)))
    @test modify(
        wix -> wix.ctx => wix.v,
        (a=[(a=1,)], b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        (keyed(@o(_.a)) ++ keyed(@o(_.b))) ⨟ @o(_[∗].a)ᵢ
    ) == (a=[(a=:a=>1,)], b=(x=(a=:b=>'a',), y=(a=:b=>'b',), z=(a=:b=>'c',)))
    @test modify(
        wix -> wix.ctx => wix.v,
        (a=1, b=(x=(a='a',), y=(a='b',), z=(a='c',))),
        @o(_.b) ⨟ keyed(Elements()) ⨟ Elements()
    ) == (a=1, b=(x=(a=:x=>'a',), y=(a=:y=>'b',), z=(a=:z=>'c',)))

    AccessorsExtra.@allinferred modify begin
    @test modify(
        wix -> wix.v / wix.ctx.total,
        ((x=5, total=10,), (x=2, total=20,), (x=3, total=8,)),
        Elements() ⨟ selfcontext() ⨟ @o(_.x)
    ) == ((x=0.5, total=10,), (x=0.1, total=20,), (x=0.375, total=8,))
    @test modify(
        wix -> wix.v / wix.ctx,
        ((x=5, total=10,), (x=2, total=20,), (x=3, total=8,)),
        Elements() ⨟ selfcontext(r -> r.total) ⨟ @o(_.x)
    ) == ((x=0.5, total=10,), (x=0.1, total=20,), (x=0.375, total=8,))

    str = "abc def 5 x y z 123"
    o = @o(eachmatch(r"\w+", _)) ⨟ enumerated(Elements())
    @test map(wix -> "$(wix.v.match)_$(wix.ctx)", getall(str, o)) == ["abc_1", "def_2", "5_3", "x_4", "y_5", "z_6", "123_7"]
    @test modify(
        wix -> "$(wix.v.match)_$(wix.ctx)",
        str,
        o
    ) == "abc_1 def_2 5_3 x_4 y_5 z_6 123_7"
    @test modify(
        wix -> wix.v + wix.ctx,
        str,
        @o(eachmatch(r"\d+", _)) ⨟ enumerated(Elements()) ⨟ @o(parse(Int, _.match))
    ) == "abc def 6 x y z 125"
    @test modify(
        wix -> "$(wix.ctx):$(wix.v)",
        "2022-03-15",
        @o(match(r"(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})", _)) ⨟ keyed(Elements())
    ) == "y:2022-m:03-d:15"
    end

    data = [
        (a=1, bs=[10, 11, 12]),
        (a=2, bs=[20, 21]),
    ]
    o = @o _[∗] |> selfcontext() |> _.bs[∗]
    @test map(x -> (;x.ctx.a, b=x.v), getall(data, o)) == [(a = 1, b = 10), (a = 1, b = 11), (a = 1, b = 12), (a = 2, b = 20), (a = 2, b = 21)]
    @test modify(x -> 100*x.ctx.a + x.v, data, o) == [
        (a=1, bs=[110, 111, 112]),
        (a=2, bs=[220, 221]),
    ]

    o = keyed(∗) ⨟ @o(_.bs) ⨟ keyed(∗)
    @test map(x -> (x.ctx[1], x.ctx[2], x.v), getall(data, o)) == [(1, 1, 10), (1, 2, 11), (1, 3, 12), (2, 1, 20), (2, 2, 21)]
    @test modify(x -> (x.ctx[1], x.ctx[2], x.v), data, o) == [(a = 1, bs = [(1, 1, 10), (1, 2, 11), (1, 3, 12)]), (a = 2, bs = [(2, 1, 20), (2, 2, 21)])]
    o = keyed(∗) ⨟ keyed(@o(_.bs)) ⨟ keyed(∗)
    @test map(x -> (x.ctx..., x.v), getall(data, o)) == [(1, :bs, 1, 10), (1, :bs, 2, 11), (1, :bs, 3, 12), (2, :bs, 1, 20), (2, :bs, 2, 21)]
    @test modify(x -> (x.ctx..., x.v), data, o) ==
        [(a = 1, bs = [(1, :bs, 1, 10), (1, :bs, 2, 11), (1, :bs, 3, 12)]), (a = 2, bs = [(2, :bs, 1, 20), (2, :bs, 2, 21)])]
end

@testitem "stripcontext" begin
    using AccessorsExtra: decompose, ConcatOptics
    (==ᶠ(x::T, y::T) where {T}) = x === y
    ==ᶠ(x, y) = all(filter(!=(identity), decompose(x)) .==ᶠ filter(!=(identity), decompose(y)))
    ==ᶠ(x::ConcatOptics, y::ConcatOptics) = all(x.optics .==ᶠ y.optics)

    @testset for o in (
        log,
        (@o _.a),
        (@o _[∗].a),
        (@o _[∗].a) ++ (@o _[1]),
    )
        @test !hascontext(o)
        @test stripcontext(o) === o
    end
    @testset for o in (
        (@o _.a) |> enumerated,
        (@o _[∗].a) |> enumerated,
        (@o _ |> enumerated(∗) |> _.a),
        (@o _ |> keyed(∗) |> _.a),
        ((@o _[∗].a) ++ (@o _[1])) |> enumerated,
        ((@o _[∗].a) ++ (@o _[1])) |> selfcontext,
        ((@o _ |> keyed(∗) |> _.a) ++ keyed(@o _[1])) |> enumerated,
        ((@o _ |> keyed(∗) |> _.a) ++ keyed(@o _[1])),
    )
        @test hascontext(o)
        @test stripcontext(o) != o
    end

    @test stripcontext((a=1, b=:x)) === (a=1, b=:x)
    @test stripcontext(AccessorsExtra.ValWithContext(1, 2)) === 2
    @test stripcontext(keyed(Elements())) ==ᶠ Elements()
    @test stripcontext(keyed(Elements()) ∘ @o(_.a)) ==ᶠ Elements() ∘ @o(_.a)
    @test stripcontext(keyed(Elements()) ∘ @o(_.a) ∘ @o(_.b)) ==ᶠ Elements() ∘ @o(_.a) ∘ @o(_.b)
    @test stripcontext(Elements() ∘ keyed(Elements()) ∘ @o(_.a) ∘ @o(convert(Int, _) + 1)) ==ᶠ Elements() ∘ Elements() ∘ @o(_.a) ∘ @o(convert(Int, _) + 1)
    @test stripcontext((keyed(@o(_.a)) ++ keyed(@o(_.b))) ∘ @o(_[∗].a)ᵢ) ==ᶠ (@o(_.a) ++ @o(_.b)) ∘ @o(_[∗].a)
    @test stripcontext(Elements() ∘ selfcontext(r -> r.total) ∘ @o(_.x)) ==ᶠ Elements() ∘ @o(_.x)
    re = r"\d+"
    @test stripcontext(@o(eachmatch(re, _)) ∘ enumerated(Elements()) ∘ @o(parse(Int, _.match))) ==ᶠ @o(eachmatch(re, _)) ∘ Elements() ∘ @o(parse(Int, _.match))

    Accessors.test_getset_laws(stripcontext, @o(_.a), (@o _.x), identity)
    Accessors.test_getset_laws(stripcontext, keyed(Elements()), (@o _.x), identity)
    Accessors.test_getset_laws(stripcontext, selfcontext(x -> x + 1), identity, identity)
end
