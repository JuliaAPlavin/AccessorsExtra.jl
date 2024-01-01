module StructArraysExt
using StructArrays
using AccessorsExtra.Accessors
using AccessorsExtra.ConstructionBase

ConstructionBase.setproperties(x::StructArray, patch::NamedTuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))
ConstructionBase.setproperties(x::StructArray{<:Tuple}, patch::Tuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))

end
