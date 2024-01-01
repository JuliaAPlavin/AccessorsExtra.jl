# XXX: should upstream all of these
module ColorTypesExt

import AccessorsExtra: set, delete
using ColorTypes

set(c::Colorant, ::typeof(alpha), alpha) = coloralpha(c, alpha)
delete(c::Colorant, ::typeof(alpha)) = color(c)

end
