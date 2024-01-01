
struct MaybeOptic{O,D}
    o::O
    default::D
end

export maybe
maybe(o; default=nothing) = MaybeOptic(o, default)

Accessors.OpticStyle(::Type{<:MaybeOptic}) = Val(:maybe)

Accessors.composed_optic_style(m::Val{:maybe}, ::Any) = m
Accessors.composed_optic_style(::Any, m::Val{:maybe}) = m

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
    


(o::MaybeOptic{<:IndexLens})(obj::AbstractArray) =
    checkbounds(Bool, obj, o.o.indices...) ? o.o(obj) : o.default

function Accessors.set(obj::AbstractArray, o::MaybeOptic{<:IndexLens}, val)
    if isnothing(val)
        checkbounds(Bool, obj, o.o.indices...) ? delete(obj, o.o) : obj
    else
        checkbounds(Bool, obj, o.o.indices...) ? set(obj, o.o, val) : insert(obj, o.o, val)
    end
end

function Accessors.modify(f, obj::AbstractArray, o::MaybeOptic{<:IndexLens})
    if checkbounds(Bool, obj, o.o.indices...)
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
