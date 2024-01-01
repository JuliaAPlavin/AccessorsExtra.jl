module StructArraysExt
using StructArrays
using AccessorsExtra: PropertyFunction, Placeholder
using AccessorsExtra.Accessors
using AccessorsExtra.ConstructionBase

ConstructionBase.setproperties(x::StructArray, patch::NamedTuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))
ConstructionBase.setproperties(x::StructArray{<:Tuple}, patch::Tuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))

Base.map(f::ComposedFunction{<:Any, <:PropertyLens}, x::StructArray) = map(f.outer, map(f.inner, x))
Base.map(f::PropertyLens, x::StructArray) = f(x)
Base.map(f::PropertyFunction, x::StructArray) = map(f.func, extract(x, f.props_nt))

extract(x::StructArray, props_nt::NamedTuple) = StructArray(extract(StructArrays.components(x), props_nt))
extract(x::NamedTuple, props_nt::NamedTuple{KS}) where {KS} = NamedTuple{KS}(map(extract, values(x[KS]), values(props_nt)))

# these should work equally well, but hit inference recursion limit:
# extract(x::StructArray, props_nt::NamedTuple) = @modify(cs -> extract(cs, props_nt), StructArrays.components(x))
# extract(x::NamedTuple, props_nt::NamedTuple{KS}) where {KS} = map(extract, x[KS], props_nt)

extract(x, ::Placeholder) = x

end
