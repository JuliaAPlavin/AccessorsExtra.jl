module UnitfulExt

using Unitful
import AccessorsExtra: _split_unitstr_from_optic

_split_unitstr_from_optic(_, o::Base.Fix1{typeof(ustrip)}) = (identity, string(o.x))
_split_unitstr_from_optic(obj, o::typeof(ustrip)) = _split_unitstr_from_optic(obj, Base.Fix1(ustrip, unit(obj)))
_split_unitstr_from_optic(::Type{Union{}}, o::typeof(ustrip)) = (identity, nothing)

end
