module StatsBaseExt

using StatsBase
import AccessorsExtra: hasoptic

hasoptic(x::AbstractArray, ::Union{typeof(mad),Base.Fix2{typeof(quantile)},Base.Fix2{typeof(percentile)}}) = !isempty(x)

end
