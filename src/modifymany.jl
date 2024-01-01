@inline modify(f, A::Tuple, ::Elements, Bs::Tuple...) = map(f, A, Bs...)
@inline modify(f, A::NTuple{N,Any}, ::Elements, B::Union{Vector,NamedTuple}) where {N} = ntuple(i -> f(A[i], B[i]), Val(N))
@inline modify(f, A::NamedTuple, ::Elements, Bs...) = @modify(t -> modify(f, t, ∗, Bs...), Tuple(A))
@inline modify(f, A::Vector, ::Elements, Bs...) = map(f, A, Bs...)

@inline modify(f, A::Tuple, ::Keyed{Elements}, B::Tuple) = map(f, A, B)
@inline modify(f, A::NTuple{N,Any}, ::Keyed{Elements}, B::Vector) where {N} = ntuple(i -> f(A[i], B[i]), Val(N))
@inline modify(f, A::Vector, ::Keyed{Elements}, B::Union{Tuple,Vector}) = map(f, A, B)
@inline modify(f, A::NamedTuple{KS}, ::Keyed{Elements}, B) where {KS} =
    NamedTuple{KS}(map(KS) do k
        f(A[k], B[k])
    end)
