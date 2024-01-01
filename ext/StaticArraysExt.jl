module StaticArraysExt
using StaticArrays
using StaticArrays: norm
import AccessorsExtra: set, construct
using AccessorsExtra: PropertyLens

construct(T::Type{SVector{N}}, ps::Vararg{Pair}) where {N} = T(construct(NTuple{N}, ps...))
construct(T::Type{SVector{N,ET}}, ps::Vararg{Pair}) where {N,ET} = T(construct(NTuple{N,ET}, ps...))

construct(T::Type{SVector{N}}, args::Vararg{<:Pair{<:PropertyLens}}) where {N} = _construct(T, args...)
construct(T::Type{SVector{N,ET}}, args::Vararg{<:Pair{<:PropertyLens}}) where {N,ET} = _construct(T, args...)
function _construct(T::Type{<:SVector{N}}, args::Vararg{<:Pair{<:PropertyLens}}) where {N}
    @assert N == length(args)
    foldl(args; init=zero(T)) do acc, a
        set(acc, first(a), last(a))
    end
end

set(obj::Tuple, ::Type{SVector}, val::SVector) = Tuple(val)

end
