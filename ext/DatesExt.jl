module DatesExt
using Dates
import AccessorsExtra: set, FixArgsT, Placeholder

set(x::AbstractString, f::FixArgsT(parse, (Type, Placeholder, DateFormat)), y) = Dates.format(y, f.args[3])

end
