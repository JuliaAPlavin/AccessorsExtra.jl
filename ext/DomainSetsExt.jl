module DomainSetsExt
using DomainSets
import AccessorsExtra: set, setproperties

set(d::Rectangle, ::typeof(components), v) = setproperties(d, a=leftendpoint.(v), b=rightendpoint.(v))

end
