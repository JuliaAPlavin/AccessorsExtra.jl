struct MaybeOptic{O,D}
    o::O
    default::D
end

maybe(o; default=nothing) = MaybeOptic(o, default)

OpticStyle(::Type{<:MaybeOptic}) = Val(:maybe)

Accessors.composed_optic_style(m::Val{:maybe}, ::Any) = m
Accessors.composed_optic_style(::Any, m::Val{:maybe}) = m
Accessors.composed_optic_style(::Val{:maybe}, m::Val{:maybe}) = m

@inline function Accessors._set(obj, optic::ComposedFunction, val, ::Val{:maybe})
    inner_obj = optic.inner(obj)
    inner_val = set(inner_obj, optic.outer, val)
    set(obj, optic.inner, inner_val)
end

function Accessors._modify(f, obj, optic::ComposedFunction, ::Val{:maybe})
    otr = optic.outer
    inr = optic.inner
    modify(obj, inr) do o1
        modify(f, o1, otr)
    end
end

(o::MaybeOptic)(obj) = hasoptic(obj, o.o) ? o.o(obj) : o.default
set(obj, o::MaybeOptic, val::Nothing) = hasoptic(obj, o.o) ? delete(obj, o.o) : obj
set(obj, o::MaybeOptic, val) = hasoptic(obj, o.o) ? set(obj, o.o, val) : insert(obj, o.o, val)

function modify(f, obj, o::MaybeOptic)
    if hasoptic(obj, o.o)
        # like modify(f, obj, o.o), but can delete
        oldv = o.o(obj)
        @assert !isnothing(oldv)
        newv = f(oldv)
        # should delete if newv == default?
        isnothing(newv) ? delete(obj, o.o) : set(obj, o.o, newv)
    else
        # should insert if f(nothing) is not nothing?
        obj
    end
end


struct OSomething{OS}
    os::OS
end
osomething(optics...) = OSomething(optics)
(o::OSomething)(obj) = hasoptic(obj, first(o.os)) ? first(o.os)(obj) : (@delete first(o.os))(obj)
(o::OSomething{Tuple{}})(obj) = error("no optic in osomething applicable to $obj")
set(obj, o::OSomething, val) = hasoptic(obj, first(o.os)) ? set(obj, first(o.os), val) : set(obj, (@delete first(o.os)), val)
set(obj, o::OSomething{Tuple{}}, val) = error("no optic in osomething applicable to $obj")


hasoptic(obj::AbstractArray, o::IndexLens) = checkbounds(Bool, obj, o.indices...)
hasoptic(obj::Tuple, o::IndexLens) = only(o.indices) in keys(obj)
hasoptic(obj, o::IndexLens) = haskey(obj, only(o.indices))
hasoptic(obj, ::PropertyLens{P}) where {P} = hasproperty(obj, P)
