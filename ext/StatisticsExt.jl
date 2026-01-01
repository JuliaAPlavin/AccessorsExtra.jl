module StatisticsExt

using Statistics
import AccessorsExtra: hasoptic

hasoptic(x::AbstractArray, ::Union{typeof(mean),typeof(median),typeof(std)}) = !isempty(x)

end
