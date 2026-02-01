module UnitfulExt

using Unitful
import AccessorsExtra: _split_unitstr_from_optic, _shortstring, _chooseoptic_bytype, Children

_split_unitstr_from_optic(_, o::Base.Fix1{typeof(ustrip)}) = (identity, string(o.x))
_split_unitstr_from_optic(obj, o::typeof(ustrip)) = _split_unitstr_from_optic(obj, Base.Fix1(ustrip, unit(obj)))
_split_unitstr_from_optic(::Type{Union{}}, o::typeof(ustrip)) = (identity, nothing)

# eg ustrip(u"m", x) -> "x [m]":
_shortstring(prev, o::Base.Fix1{typeof(ustrip)}) = "$prev [$(o.x)]"
# eg x |> u"m" -> "x" (because units are in the value now, will be shown elsewhere):
_shortstring(prev, o::Unitful.FreeUnits) = prev


@inline _chooseoptic_bytype(::Type{T}, ::Children) where {T<:Unitful.AbstractQuantity} = Base.Fix1(ustrip, unit(T))

end
