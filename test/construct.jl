@testitem "basic usage" begin
    ==ₜ(_, _) = false
    ==ₜ(x::T, y::T) where T = x == y

    AccessorsExtra.@allinferred construct begin
        @test construct(Complex, @o(_.re) => 1, @o(_.im) => 2)::Complex{Int} === 1 + 2im
        @test_broken construct(Complex, @o(_.im) => 1, @o(_.re) => 2)::Complex{Int} === 1 + 2im
        @test construct(ComplexF32, @o(_.re) => 1, @o(_.im) => 2)::ComplexF32 === 1f0 + 2f0im
        @test_throws InexactError construct(Complex{Int}, abs => 1., angle => π/2)

        @test construct(Tuple, only => 1) === (1,)
        @test construct(Tuple{Float64}, only => 1) === (1.0,)
        @test_throws Exception construct(Tuple{String}, only => 1)
        @test_throws Exception construct(Tuple{Int, Int}, only => 1)

        @test construct(Vector, only => 1) ==ₜ [1]
        @test construct(Vector{Float64}, only => 1) ==ₜ [1.0]
        @test_throws Exception construct(Vector{String}, only => 1)

        @test construct(Set, only => 1) ==ₜ Set((1,))
        @test construct(Set{Float64}, only => 1) ==ₜ Set((1.0,))
        @test_throws Exception construct(Set{String}, only => 1,)

        @test construct(NamedTuple, @o(_.a) => 1, @o(_.b) => "") === (a=1, b="")
    end
end

@testitem "laws" begin
    using StaticArrays
    using LinearAlgebra: norm
    using AccessorsExtra: test_construct_laws

    test_construct_laws(Complex, @o(_.re) => 1, @o(_.im) => 2)
    test_construct_laws(Complex{Int}, @o(_.re) => 1, @o(_.im) => 2)
    test_construct_laws(ComplexF32, @o(_.re) => 1, @o(_.im) => 2)
    test_construct_laws(Complex, @o(_.re) => 1., @o(_.im) => 2)
    test_construct_laws(Complex, abs => 1., angle => π/2)
    test_construct_laws(ComplexF32, abs => 1., angle => π/2; cmp=(≈))

    test_construct_laws(Tuple, only => 1)
    test_construct_laws(Tuple{Int}, only => 1)
    test_construct_laws(Tuple{Float64}, only => 1)

    test_construct_laws(Vector, only => 1)
    test_construct_laws(Vector{Int}, only => 1)
    test_construct_laws(Vector{Float64}, only => 1)

    test_construct_laws(Set, only => 1)
    test_construct_laws(Set{Int}, only => 1)
    test_construct_laws(Set{Float64}, only => 1)

    test_construct_laws(NamedTuple{(:a,)}, only => 1)
    test_construct_laws(NamedTuple, @o(_.a) => 1)
    test_construct_laws(NamedTuple, @o(_.a) => 1, @o(_.b) => "")

    @testset for T in (Tuple{}, SVector{0}, SVector{0,String})
        test_construct_laws(T)
    end
    @testset for T in (Tuple{Any}, Tuple{Int}, Tuple{Float32}, Tuple{Real}, SVector{1}, SVector{1,Int}, SVector{1,Float64})
        test_construct_laws(T, only => 2)
        test_construct_laws(T, first => 3)
        test_construct_laws(T, last => 4)
    end
    @testset for T in (Tuple{Any,Any}, Tuple{Float64,Float32}, Tuple{Real,Real}, SVector{2}, SVector{2,Float32}, SVector{2,Float64})
        test_construct_laws(T, first => 4, last => 5)
        test_construct_laws(T, @o(hypot(_...)) => 3, @o(atan(_...)) => 0.123; cmp=(x,y) -> isapprox(x,y,rtol=√eps(Float32)))
        test_construct_laws(T, norm => 3, @o(atan(_...)) => 0.123; cmp=(x,y) -> isapprox(x,y,rtol=√eps(Float32)))
    end
    test_construct_laws(SVector{2}, @o(_.x) => 4, @o(_.y) => 5)
    test_construct_laws(SVector{2}, @o(_.y) => 4, @o(_.x) => 5)
    test_construct_laws(SVector{2,Float32}, @o(_.x) => 4, @o(_.y) => 5)
end

@testitem "macro" begin
    @test @construct(Complex, _.re = 1, _.im = 2)::Complex{Int} === 1 + 2im
    @test (@construct Complex{Int}  _.re = 1 _.im = 2)::Complex{Int} === 1 + 2im
    res = @construct Complex begin
        _.re = 1
        _.im = 2
    end
    @test res::Complex{Int} === 1 + 2im
    res = @construct Complex{Int} begin
        _.re = 1
        _.im = 2
    end
    @test res::Complex{Int} === 1 + 2im
    res = @construct NamedTuple begin
        _.a = @construct Complex  abs(_) = 1 angle(_) = π
        _.b = @construct Vector  only(_) = 10
        _.c = 123
    end
    @test res == (a=-1, b=[10], c=123)
    res = @construct NamedTuple begin
        _.a = construct(Complex, @o(_.re) => -1, @o(_.im) => 0)
        _.b = construct(Vector, only => 10)
        _.c = 123
    end
    @test res == (a=-1, b=[10], c=123)
end

@testitem "invertible pre-func" begin
    using StaticArrays
    using LinearAlgebra: norm
    using AccessorsExtra: test_construct_laws

    AccessorsExtra.@allinferred construct begin

    @test construct(Complex, abs => 3, rad2deg ∘ angle => 45) ≈ 3/√2 * (1 + 1im)
    test_construct_laws(SVector{2,Float32}, norm => 3, @o(atan(_...) |> rad2deg) => 0.123; cmp=(≈))

    res = @construct SVector{2} begin
        norm(_) = 3
        atan(_...) |> rad2deg |> _ + 1 = 46
    end
    @test res ≈ SVector(3, 3) / √2
    
    end
end
