module URIsExt

using URIs
using AccessorsExtra
import AccessorsExtra.ConstructionBase: setproperties
import AccessorsExtra: set

# XXX: piracy, should upstream
setproperties(obj::URI, patch::NamedTuple) = @invoke setproperties(obj::Any, merge((uri="",), patch))

set(uri::URI, ::typeof(queryparams), qp::Dict) = @set uri.query = escapeuri(qp)
set(uri::URI, ::typeof(queryparampairs), qp::Vector{<:Pair}) = @set uri.query = escapeuri(qp)

end
