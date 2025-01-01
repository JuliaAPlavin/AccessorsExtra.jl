struct MaybeOptic{O,D}
    o::O
    default::D
end
Broadcast.broadcastable(o::MaybeOptic) = Ref(o)

"""    maybe(optic; [default=nothing])

Create an optional optic that references a value that may or may not be present in the object.

__Note:__ support for `default != nothing` is experimental and only implemented for getting, not for setting.

`maybe(o)` behaves similar to `o` itself, with the following differences:
- if the referenced value is present, `set(obj, maybe(o), nothing)` deletes it
- if the value is absent:
    - accessing `maybe(o)(obj)` returns `default`
    - `modify` doesn't do anything
    - `set` inserts the new value

Whether the referenced value is present or not, is determined by `hasoptic(obj, o)`.

`@maybe` is the macro form available for convenience: `@maybe ...` is equivalent to `maybe(@o ...)`.

## Examples

```julia
julia> o = maybe(@o _.a)

julia> o((a=1, b=2))
1
julia> o((b=2,))
# nothing

julia> set((a=1, b=2), o, 10)
(a = 10, b = 2)
julia> set((b=2,), o, 10)
(b = 2, a = 10)

julia> modify(x -> x+10, (a=1, b=2), o)
(a = 11, b = 2)
julia> modify(x -> x+10, (b=2,), o)
(b = 2,)

julia> modify(x -> x+10, ((a=1,), (a=2, b=3), (b=4,)), o ∘ Elements())
((a = 11,), (a = 12, b = 3), (b = 4,))
```
"""
maybe(o; default=nothing) = MaybeOptic(o, default)

struct MaybeStyle{P}
    parent::P
end

OpticStyle(::Type{<:MaybeOptic{O}}) where O = MaybeStyle(OpticStyle(O))

Accessors.composed_optic_style(m::MaybeStyle, s::Any) = MaybeStyle(Accessors.composed_optic_style(m.parent, s))
Accessors.composed_optic_style(s::Any, m::MaybeStyle) = MaybeStyle(Accessors.composed_optic_style(s, m.parent))
Accessors.composed_optic_style(ma::MaybeStyle, mb::MaybeStyle) = MaybeStyle(Accessors.composed_optic_style(ma.parent, mb.parent))

@inline Accessors._set(obj, optic::ComposedFunction, val, ::MaybeStyle{Accessors.SetBased}) =
    set(obj, optic.inner,
        set(optic.inner(obj), optic.outer, val))

@inline Accessors._set(obj, optic::ComposedFunction, val, ::MaybeStyle{Accessors.ModifyBased}) =
    modify(Returns(val), obj, optic)

Accessors._modify(f, obj, optic::ComposedFunction, ::MaybeStyle) =
    modify(obj, optic.inner) do o1
        modify(f, o1, optic.outer)
    end

(o::MaybeOptic)(obj) = hasoptic(obj, o.o) ? o.o(obj) : o.default
set(obj, o::MaybeOptic, val::Nothing) = hasoptic(obj, o.o) ? delete(obj, o.o) : obj
set(obj, o::MaybeOptic, val) = hasoptic(obj, o.o) ? set(obj, o.o, val) : insert(obj, o.o, val)

getall(obj, o::MaybeOptic) = hasoptic(obj, o.o) ? getall(obj, o.o) : ()
setall(obj, o::MaybeOptic, vals) = hasoptic(obj, o.o) ? setall(obj, o.o, vals) : obj

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
Broadcast.broadcastable(o::OSomething) = Ref(o)
osomething(optics...) = OSomething(optics)
(o::OSomething)(obj) = hasoptic(obj, first(o.os)) ? first(o.os)(obj) : (@delete first(o.os))(obj)
(o::OSomething{Tuple{}})(obj) = error("no optic in osomething applicable to $obj")
set(obj, o::OSomething, val) = hasoptic(obj, first(o.os)) ? set(obj, first(o.os), val) : set(obj, (@delete first(o.os)), val)
set(obj, o::OSomething{Tuple{}}, val) = error("no optic in osomething applicable to $obj")


oget(default::Base.Callable, obj, o) = hasoptic(obj, o) ? o(obj) : default()
oget(obj, o, default=nothing) = hasoptic(obj, o) ? o(obj) : default


set(obj, fa::FixArgs{typeof(get), <:Tuple{Placeholder,Any,Any}, <:NamedTuple{()}}, val) =
    haskey(obj, fa.args[2]) ? set(obj, IndexLens((fa.args[2],)), val) : insert(obj, IndexLens((fa.args[2],)), val)
set(obj, fa::FixArgs{typeof(get), <:Tuple{Any,Placeholder,Any}, <:NamedTuple{()}}, val) =
    haskey(obj, fa.args[3]) ? set(obj, IndexLens((fa.args[3],)), val) : insert(obj, IndexLens((fa.args[3],)), val)


hasoptic(obj, o::ComposedFunction) = hasoptic(obj, o.inner) && hasoptic(o.inner(obj), o.outer)

hasoptic(obj::AbstractArray, o::IndexLens) = checkbounds(Bool, obj, o.indices...)
hasoptic(obj::Tuple, o::IndexLens) = only(o.indices) in keys(obj)
hasoptic(obj, o::IndexLens) = haskey(obj, only(o.indices))

hasoptic(obj, ::PropertyLens{P}) where {P} = hasproperty(obj, P)

hasoptic(obj, ::typeof(first)) = hasoptic(obj, @optic _[firstindex(obj)])
hasoptic(obj, ::typeof(last)) = hasoptic(obj, @optic _[lastindex(obj)])
hasoptic(obj, ::typeof(only)) = length(obj) == 1

# should override call, set, modify for efficiency?
hasoptic(x::AbstractString, o::Base.Fix1{typeof(parse), Type{T}}) where {T} = !isnothing(tryparse(T, x))
# hasoptic(x::AbstractString, o::Base.Fix2{Type{T}}) where {T <: Union{Date, Time, DateTime}} = # XXX - what to put here?

# fallback definition
# without it: cases when hasoptic throws, but optic actually exists
# with it: cases when hasoptic=true, but optic doesn't exist
hasoptic(obj, o) = !isnothing(obj)


# convenience macros
macro oget(ref, default=nothing)
    obj, optic = parse_obj_optic(ref)
    return :($oget($obj, $optic, $default))
end

macro osomething(args...)
    return :($osomething($(map(args) do arg
        :($Accessors.@optic $arg)
    end...))) |> esc
end

macro maybe(o, default=nothing)
    return :($maybe(($Accessors.@optic $o); default=$default)) |> esc
end
