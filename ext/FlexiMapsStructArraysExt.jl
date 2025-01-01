module FlexiMapsStructArraysExt

import FlexiMaps: mapview
using StructArrays
using AccessorsExtra: ContainerOptic

mapview(f::ContainerOptic{<:Union{Tuple,NamedTuple}}, x::StructArray) = StructArray(map(o -> mapview(o, x), f.optics))

end
