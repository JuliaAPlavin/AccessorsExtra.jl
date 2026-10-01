module FlexiMapsStructArraysExt

import FlexiMaps: mapview
using StructArrays
using AccessorsExtra: ContainerOptic

# only nonempty: a StructArray needs at least one column
mapview(f::ContainerOptic{<:Union{Tuple{Any,Vararg},NamedTuple{<:Any,<:Tuple{Any,Vararg}}}}, x::StructArray) = StructArray(map(o -> mapview(o, x), f.optics))

end
