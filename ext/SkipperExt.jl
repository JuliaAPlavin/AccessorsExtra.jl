module SkipperExt

using AccessorsExtra: PROPFUNCTYPES, extract_properties_recursive, rawfunc, propspec
using Skipper

Base.map(f::PROPFUNCTYPES, x::Skipper.Skip) = map(rawfunc(f), extract_properties_recursive(x, propspec(f)))

end
