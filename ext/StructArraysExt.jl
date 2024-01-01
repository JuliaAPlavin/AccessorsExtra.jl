module StructArraysExt

using StructArrays
import AccessorsExtra: extract_properties_recursive
using AccessorsExtra.Accessors
using AccessorsExtra.ConstructionBase

# XXX: piracy, but kinda hard to upstream
ConstructionBase.setproperties(x::StructArray, patch::NamedTuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))
ConstructionBase.setproperties(x::StructArray{<:Tuple}, patch::Tuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))

extract_properties_recursive(x::StructArray, props_nt::NamedTuple) =
    StructArray(extract_properties_recursive(StructArrays.components(x), props_nt))
# should work equally well, but hits inference recursion limit:
# extract_properties_recursive(x::StructArray, props_nt::NamedTuple) = @modify(cs -> extract_properties_recursive(cs, props_nt), StructArrays.components(x))

end
