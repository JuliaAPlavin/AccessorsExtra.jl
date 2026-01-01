module MakieExt

using Makie
using AccessorsExtra
import AccessorsExtra: Children, _chooseoptic_bytype

_chooseoptic_bytype(::Type{<:Figure}, ::Children) = @optics _.layout
_chooseoptic_bytype(::Type{<:GridLayout}, ::Children) = @optics contents(_)
_chooseoptic_bytype(::Type{<:GridPosition}, ::Children) = @optics contents(_)
_chooseoptic_bytype(::Type{<:GridSubposition}, ::Children) = @optics contents(_)
_chooseoptic_bytype(::Type{<:Makie.Block}, ::Children) = concat()

end
