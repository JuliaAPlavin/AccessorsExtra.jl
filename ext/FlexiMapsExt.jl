module FlexiMapsExt

import FlexiMaps: mapview
import AccessorsExtra: PropertyFunction, PROPFUNCTYPES_ONLYEXTRA, extract_properties_recursive, propspec, rawfunc

mapview(f::PROPFUNCTYPES_ONLYEXTRA, x) =
    mapview(rawfunc(f), extract_properties_recursive(x, propspec(f)))
mapview(f::PROPFUNCTYPES_ONLYEXTRA, x::AbstractArray) =
    mapview(rawfunc(f), extract_properties_recursive(x, propspec(f)))

end
