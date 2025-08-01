module MakieExt

using Makie
using AccessorsExtra
import AccessorsExtra: Children, _chooseoptic_bytype

_chooseoptic_bytype(::Type{<:Figure}, ::Children) = @o _.layout
_chooseoptic_bytype(::Type{<:GridLayout}, ::Children) = @o contents(_)
_chooseoptic_bytype(::Type{<:GridPosition}, ::Children) = @o contents(_)
_chooseoptic_bytype(::Type{<:GridSubposition}, ::Children) = @o contents(_)
_chooseoptic_bytype(::Type{<:Makie.Block}, ::Children) = concat()
_chooseoptic_bytype(::Type{<:Makie.Axis}, ::Children) = @o _.scene.plots[∗]
_chooseoptic_bytype(::Type{<:Makie.PlotList}, ::Children) = @o _.plots[∗]

end
