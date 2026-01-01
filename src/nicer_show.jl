# some piracy, but cannot upstream: relies on @o parsing extensions here
Accessors._shortstring(prev, o::Base.Splat) = "$(o.f)($prev...)"
Accessors._shortstring(prev, o::Returns) = sprint(show, o.value)

barebones_string(optic::Base.Splat) = sprint(Accessors.show_optic, optic; context=:compact => true)
barebones_string(optic::Union{Base.Fix1,Base.Fix2}) = sprint(Accessors.show_optic, optic; context=:compact => true)
barebones_string(optic::typeof(identity)) = "_"
barebones_string(optic) = @p let
    sprint(Accessors.show_optic, optic; context=:compact => true)
    replace(__, "_." => "", "_[" => "[")
end


_split_unitstr_from_optic(o) = _split_unitstr_from_optic(Union{}, o)
_split_unitstr_from_optic(obj, o) = (o, nothing)
_split_unitstr_from_optic(obj, ::typeof(rad2deg)) = (identity, "°")
function _split_unitstr_from_optic(obj, o::ComposedFunction)
    opart, unit = _split_unitstr_from_optic(first(getall(obj, o.inner)), o.outer)
    (opart ∘₁ o.inner, unit)
end
function _split_unitstr_from_optic(::Type{T}, o::ComposedFunction) where {T}
    opart, unit = _split_unitstr_from_optic(_eltype(Base.promote_op(getall, T, typeof(o.inner))), o.outer)
    (opart ∘₁ o.inner, unit)
end
function _split_unitstr_from_optic(obj, o::AccessorsExtra.ContextOptic)
    oc = stripcontext(o)
    oshowc, unit = _split_unitstr_from_optic(obj, oc)
    (set(o, stripcontext, oshowc), unit)
end

_eltype(T) = eltype(T)
_eltype(::Type{Union{}}) = Union{}
