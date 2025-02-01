module DateFormatsExt

import AccessorsExtra: _split_unitstr_from_optic
using DateFormats

_split_unitstr_from_optic(obj, ::typeof(julian_day)) = (identity, "JD")
_split_unitstr_from_optic(obj, ::typeof(modified_julian_day)) = (identity, "MJD")
_split_unitstr_from_optic(obj, ::typeof(yeardecimal)) = (identity, "yr")
_split_unitstr_from_optic(obj, ::typeof(unix_time)) = (identity, "unix time")

end
