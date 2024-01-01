module FlexiMapsExt

import FlexiMaps: mapview
import AccessorsExtra: PropertyFunction, PROPFUNCTYPES, extract_properties_recursive, propspec, rawfunc

mapview(f::Union{PropertyFunction,ComposedFunction{<:Any,<:PropertyFunction}}, x) =
    mapview(rawfunc(f), extract_properties_recursive(x, propspec(f)))
mapview(f::Union{PropertyFunction,ComposedFunction{<:Any,<:PropertyFunction}}, x::AbstractArray) =
    mapview(rawfunc(f), extract_properties_recursive(x, propspec(f)))

end
