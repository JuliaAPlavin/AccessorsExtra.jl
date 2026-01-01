module DictArraysExt

using DictArrays
import AccessorsExtra: PROPFUNCTYPES, extract_properties_recursive, propspec, rawfunc

Base.map(f::PROPFUNCTYPES, x::DictArray) = map(rawfunc(f), extract_properties_recursive(x, propspec(f)))

extract_properties_recursive(x::DictArray, props_nt::NamedTuple{KS}) where {KS} =
    extract_properties_recursive(x[Cols(KS)], props_nt)

end
