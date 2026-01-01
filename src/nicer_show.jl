# some piracy, but cannot upstream: relies on @o parsing extensions here
Accessors._shortstring(prev, o::Base.Splat) = "$(o.f)($prev...)"
Accessors._shortstring(prev, o::Returns) = sprint(show, o.value)

barebones_string(optic) = sprint(show_optic, optic)

using Accessors: _isoperator, _need_parens, _fT_repr

# implementation almost exactly following Accessors
_shortstring(prev, o::PropertyLens{field}) where {field} =
    prev == "_" ? "$field" : "$prev.$field"
_shortstring(prev, o::IndexLens) = "$prev[$(join(repr.(o.indices), ", "))]"
_shortstring(prev, o::Union{Function,Type}) =
    _isoperator(o) ? "$(_fT_repr(o))$prev" :
    prev == "_" ? _fT_repr(o) : "$(_fT_repr(o))($prev)"
_shortstring(prev, o::Base.Fix1) = _isoperator(o.f) ? "$(o.x) $(_fT_repr(o.f)) $prev" : "$(_fT_repr(o.f))($(o.x), $prev)"
_shortstring(prev, o::Base.Fix2) = _isoperator(o.f) ? "$prev $(_fT_repr(o.f)) $(o.x)" : "$(_fT_repr(o.f))($prev, $(o.x))"
_shortstring(prev, o::Elements) = prev == "_" ? "[∗]" : "$prev[∗]"
_shortstring(prev, o::Properties) = prev == "_" ? "[∗ₚ]" : "$prev[∗ₚ]"

_shortstring(prev, o::typeof(identity)) = prev
_shortstring(prev, o::typeof(real)) = "Re($prev)"
_shortstring(prev, o::typeof(imag)) = "Im($prev)"
_shortstring(prev, o::typeof(abs)) = "|$prev|"
_shortstring(prev, o::typeof(sqrt)) = "√$prev"
_shortstring(prev, o::typeof(log10)) = "log₁₀($prev)"
_shortstring(prev, o::typeof(log)) = "ln($prev)"
_shortstring(prev, o::Base.Splat) = "$(o.f)($prev...)"
_shortstring(prev, o::Returns) = sprint(show, o.value)

function show_optic(io, optic)
    opts = deopcompose(optic)
    inner = Iterators.takewhile(x -> applicable(_shortstring, "", x), opts)
    outer = Iterators.dropwhile(x -> applicable(_shortstring, "", x), opts)
    if !isempty(outer)
        show(io, opcompose(outer...))
    end
    if !isempty(inner) && !isempty(outer)
        print(io, " ∘ ")
    end
    if !isempty(inner)
        shortstr = reduce(inner; init=("_", false)) do (prev, need_parens_prev), o
            # if _need_parens is true for this o and the one before, wrap the previous one in parentheses
            if need_parens_prev && _need_parens(o)
                prev = "($prev)"
            end
            _shortstring(prev, o), _need_parens(o)
        end |> first
        print(io, shortstr)
    end
end

# some piracy:
const _OpticsTypes = Union{IndexLens,PropertyLens,Elements,Properties}
for OT in [:IndexLens, :PropertyLens, :Elements, :Properties]
    @eval Base.show(io::IO, ::MIME"text/plain", optic::$OT) = show_optic(io, optic)
end
# Base.show(io::IO, ::MIME"text/plain", optic::_OpticsTypes) = show(io, optic)
Base.show(io::IO, ::MIME"text/plain", optic::ComposedFunction{<:Any, <:_OpticsTypes}) = show_optic(io, optic)
Base.show(io::IO, ::MIME"text/plain", optic::ComposedFunction{typeof(!), <:_OpticsTypes}) = show_optic(io, optic)



# only needed for nicer show? maybe remove, given generic show() implementation above?

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
