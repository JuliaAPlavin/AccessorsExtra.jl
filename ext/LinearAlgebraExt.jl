module LinearAlgebraExt

import AccessorsExtra: construct
using LinearAlgebra: norm

construct(T::Type{<:Tuple{Any,Any}}, (_, n)::Pair{typeof(norm)}, ap::Pair{typeof(splat(atan))})::T = construct(T, splat(hypot) => n, ap)

end
