module StaticArraysExt
using StaticArrays
using StaticArrays: norm
import AccessorsExtra: construct

construct(T::Type{<:SVector{0}}) = T()
construct(T::Type{<:SVector{1}}, (_, x)::Pair{typeof(only)}) = T(x)
construct(T::Type{<:SVector{1}}, (_, x)::Pair{typeof(first)}) = T(x)
construct(T::Type{<:SVector{1}}, (_, x)::Pair{typeof(last)}) = T(x)
construct(T::Type{<:SVector{2}}, (_, x)::Pair{typeof(first)}, (_, y)::Pair{typeof(last)}) = T(x, y)
construct(T::Type{<:SVector{2}}, (_, n)::Pair{typeof(norm)}, (_, a)::Pair{typeof(splat(atan))}) = T(n .* sincos(a))

end
