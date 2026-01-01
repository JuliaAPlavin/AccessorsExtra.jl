module FlexiGroupsExt

using FlexiGroups
using AccessorsExtra: PROPFUNCTYPES, rawfunc, extract_properties_recursive, propspec

# disambiguate:
Base.map(f::PROPFUNCTYPES, x::FlexiGroups.GroupArray) = map(rawfunc(f), extract_properties_recursive(x, propspec(f)))

end
