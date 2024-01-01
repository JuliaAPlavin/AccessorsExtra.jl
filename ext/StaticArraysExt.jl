module StaticArraysExt
using StaticArrays
using StaticArrays: norm
import AccessorsExtra: construct

construct(T::Type{SVector{N}}, ps::Vararg{Pair}) where {N} = T(construct(NTuple{N}, ps...))
construct(T::Type{SVector{N,ET}}, ps::Vararg{Pair}) where {N,ET} = T(construct(NTuple{N,ET}, ps...))

end
