@inline modify(f, A::Tuple, ::Elements, Bs::Tuple...) = map(f, A, Bs...)
@inline modify(f, A::NTuple{N,Any}, ::Elements, B::Union{Vector,NamedTuple}) where {N} = ntuple(i -> f(A[i], B[i]), Val(N))
@inline modify(f, A::NamedTuple, ::Elements, Bs...) = @modify(t -> modify(f, t, ∗, Bs...), Tuple(A))
@inline modify(f, A::Vector, ::Elements, Bs...) = map(f, A, Bs...)

@inline modify(f, A::NamedTuple{KS}, ::Properties, B::NamedTuple) where {KS} = map(f, A, B[KS])
@inline modify(f, A::NTuple{N,Any}, ::Properties, B::NTuple{N,Any}) where {N} = map(f, A, B)
@inline modify(f, A::Tuple, ::Properties, B::Tuple) = error("modify not supported for different lengths: $(length(A)) vs $(length(B))")
@inline modify(f, A, ::Properties, Bs...) = setproperties(A, modify(f, getproperties(A), Properties(), getproperties.(Bs)...))

modify(f, A, o::ComposedFunction, B) =
    modify(A, o.inner, B) do a, b
        modify(f, a, o.outer, b)
    end

@inline modify(f, A, o, B) =
    modify(A, o) do a
        f(a, o(B))
    end

# functionality is useful: "take elements according to their indices, not iteration order"
# but it shouldn't be keyed(∗) because it means different things for a single argument
# @inline modify(f, A::Tuple, ::Keyed{Elements}, B::Tuple) = map(f, A, B)
# @inline modify(f, A::NTuple{N,Any}, ::Keyed{Elements}, B::Vector) where {N} = ntuple(i -> f(A[i], B[i]), Val(N))
# @inline modify(f, A::Vector, ::Keyed{Elements}, B::Union{Tuple,Vector}) = map(f, A, B)
# @inline modify(f, A::NamedTuple{KS}, ::Keyed{Elements}, B) where {KS} =
#     NamedTuple{KS}(map(KS) do k
#         f(A[k], B[k])
#     end)
