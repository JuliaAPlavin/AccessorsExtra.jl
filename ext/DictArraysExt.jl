module DictArraysExt

using DictArrays
import AccessorsExtra: PropertyFunction, extract_properties_recursive

extract_properties_recursive(x::DictArray, props_nt::NamedTuple{KS}) where {KS} =
    extract_properties_recursive(x[Cols(KS)], props_nt)

end
