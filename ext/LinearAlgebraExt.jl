module LinearAlgebraExt

import AccessorsExtra: set, @set, construct
using LinearAlgebra: norm, diag, diagind

# XXX: upstream
set(A, ::typeof(diag), val) = @set A[diagind(A)] = val

construct(T::Type{<:Tuple{Any,Any}}, (_, n)::Pair{typeof(norm)}, ap::Pair{typeof(splat(atan))})::T = construct(T, splat(hypot) => n, ap)

end
