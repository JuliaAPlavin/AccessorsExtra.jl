@testitem "Dictionaries" begin
    using Dictionaries
    using UnionCollections
    const UnionDictionary = Base.get_extension(UnionCollections, :DictionariesExt).UnionDictionary

    dct = dictionary([:a => 1, :b => 2])
    DT = Dictionary{Symbol,Float64}
    @test @set(dct[:a] = 10)::typeof(dct) == dictionary([:a => 10, :b => 2])
    @test @set(dct[:a] = 10.)::DT == dictionary([:a => 10, :b => 2])
    @test @delete(dct[:a])::typeof(dct) == dictionary([:b => 2])
    @test @insert(dct[:c] = 5.)::DT == dictionary([:a => 1, :b => 2, :c => 5])

    dct = ArrayDictionary(dct)
    DT = ArrayDictionary{Symbol,Float64}
    @test @set(dct[:a] = 10)::typeof(dct) == dictionary([:a => 10, :b => 2])
    @test @set(dct[:a] = 10.)::DT == dictionary([:a => 10, :b => 2])
    @test @delete(dct[:a])::typeof(dct) == dictionary([:b => 2])
    @test @insert(dct[:c] = 5.)::DT == dictionary([:a => 1, :b => 2, :c => 5])

    dct = unioncollection(dct)
    DT = UnionDictionary{Symbol,Union{Int,Float64}}
    @test @set(dct[:a] = 10)::UnionDictionary{Symbol,Int} == dictionary([:a => 10, :b => 2])
    @test @set(dct[:a] = 10.)::DT == dictionary([:a => 10, :b => 2])
    @test @delete(dct[:a])::UnionDictionary{Symbol,Int} == dictionary([:b => 2])
    @test @insert(dct[:c] = 5.)::DT == dictionary([:a => 1, :b => 2, :c => 5])
end

@testitem "StructArrays" begin
    using StructArrays
    using StructArrays.Tables

    s = StructArray(a=[1, 2, 3])
    @test setproperties(s, a=10:12)::StructArray == StructArray(a=10:12)
    @test_throws ArgumentError setproperties(s, b=10:12)
    @test @modify(c -> c .+ 1, s |> Properties()) == StructArray(a=[2, 3, 4])

    @test (@set Tables.columns(s) = (10:12,)) == StructArray((10:12,))
    @test (@set Tables.columns(s) = (b=10:12,)) == StructArray(b=10:12)

    s = StructArray(([1, 2, 3],))
    @test setproperties(s, (10:12,))::StructArray == StructArray((10:12,))
    @test @modify(c -> c .+ 1, s |> Properties()) == StructArray(([2, 3, 4],))

    s = StructArray(([1, 2, 3], [4, 5, 6]))
    @test (@set propertynames(s) = (:a, :b)) === StructArray(a=s.:1, b=s.:2)
    @test (@set propertynames(s) = (1, 2)) === s
    s = StructArray(a=[1, 2, 3], b=[4, 5, 6])
    @test (@set propertynames(s) = (:a, :b)) === s
    @test (@set propertynames(s) = (:c, :d)) === StructArray(c=s.a, d=s.b)
    @test (@set propertynames(s) = (1, 2)) === StructArray((s.a, s.b))
end

@testitem "URIs" begin
    using URIs

    uri = URI("https://google.com/user?key=value")
    @test (@set uri.host = "github.com") == URI("https://github.com/user?key=value")
    @test (@set uri.path = "/abc/def") == URI("https://google.com/abc/def?key=value")
    @test URIs.uristring(@set uri.path = "/abc/def") == "https://google.com/abc/def?key=value"
end

@testitem "StaticArrays" begin
    using StaticArrays

    Accessors.test_getset_laws(Tuple, SVector(1, 2, 3), (4., 5, 6), (:a, :b, :c))
    Accessors.test_getset_laws(SVector, (1, 2, 3), SVector(4., 5, 6), SVector(:a, :b, :c))
    Accessors.test_getset_laws(SVector, (1., 2, 3), SVector(4., 5, 6), SVector(:a, :b, :c))
end

@testitem "DomainSets" begin
    using DomainSets; using DomainSets: ×
    using StaticArrays

    Accessors.test_getset_laws(components, (1..2) × (2..5), SVector((10.0..20.0), (1..0)), SVector((-1..1) × (0..2)))
    # Accessors.test_getset_laws(components, (1..2) × (2..5), ((10.0..20.0), (1..0)), ((-1..1) × (0..2)))
end


@testitem "Distributions" begin
    using InverseFunctions
    using Distributions

    # https://github.com/JuliaStats/Distributions.jl/pull/1685
    using Distributions
    @testset for d in (Normal(1.5, 2.3),)
        # unbounded distribution: can invert cdf at any point in [0..1]
        @testset for f in (cdf, ccdf, logcdf, logccdf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 1.2345)
            InverseFunctions.test_inverse(Base.Fix1(f, d), -Inf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), Inf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), -1.2345)
            @test_throws "not defined at 5" inverse(Base.Fix1(f, d))(5)
        end
    end
    @testset for d in (Uniform(1, 2), truncated(Normal(1.5, 2.3), 1, 2))
        # bounded distribution: cannot invert cdf at 0 and 1
        @testset for f in (cdf, ccdf, logcdf, logccdf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 1.2345)
            @test_throws "not defined at 5" inverse(Base.Fix1(f, d))(5)
            @test_throws "not defined at 0" inverse(Base.Fix1(f, d))(0)
            @test_throws "not defined at 1" inverse(Base.Fix1(f, d))(1)
        end
    end

    @testset for d in (Normal(1.5, 2.3), Uniform(1, 2), truncated(Normal(1.5, 2.3), 1, 2))
        # quantile can be inverted everywhere for any continuous distribution
        @testset for f in (quantile, cquantile)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 0.1234)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 0)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 1)
        end
        @testset for f in (invlogcdf, invlogccdf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), -0.1234)
            InverseFunctions.test_inverse(Base.Fix1(f, d), -Inf)
            InverseFunctions.test_inverse(Base.Fix1(f, d), 0)
        end
    end
end

@testitem "ColorTypes" begin
    using ColorTypes

    c = RGB(0.5, 0.2, 1)
    ca = RGBA(0.5, 0.2, 1, 0.2)
    @test RGBA(0.5, 0.2, 1, 0.1) === @set alpha(c) = 0.1
    @test RGBA(0.5, 0.2, 1, 0.1) === @set alpha(c) *= 0.1
    @test RGBA(0.5, 0.2, 1, 0.1) === @set alpha(ca) = 0.1
    @test RGBA(0.5, 0.2, 1, 0.1) === @set alpha(ca) *= 0.5

    @test c === @delete alpha(c)
    @test c === @delete alpha(ca)
end

@testitem "Skipper" begin
    # test that no method ambiguity
    using Skipper
    using FlexiMaps
    using StructArrays

    @test map(x->x, skip(isodd, 1:10)) == [2, 4, 6, 8, 10]
    @test collect(mapview(x->x, skip(isodd, 1:10))) == [2, 4, 6, 8, 10]
    @test map((@o _.x), skip((@o isodd(_.x)), StructArray(x=1:10))) == [2, 4, 6, 8, 10]
    @test collect(mapview((@o _.x), skip((@o isodd(_.x)), StructArray(x=1:10)))) == [2, 4, 6, 8, 10]
end
