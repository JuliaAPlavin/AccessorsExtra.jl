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

@inline Accessors._modify(f, obj, optic::ComposedFunction, ::MaybeStyle) =
    modify(obj, optic.inner) do o1
        modify(f, o1, optic.outer)
    end

@inline (o::MaybeOptic)(obj) = hasoptic(obj, o.o) ? o.o(obj) : o.default
@inline set(obj, o::MaybeOptic, val::Nothing) = hasoptic(obj, o.o) ? delete(obj, o.o) : obj
@inline set(obj, o::MaybeOptic, val) = hasoptic(obj, o.o) ? set(obj, o.o, val) : insert(obj, o.o, val)

@inline getall(obj, o::MaybeOptic) = (o(obj),)
@inline setall(obj, o::MaybeOptic, vals) = hasoptic(obj, o.o) ? setall(obj, o.o, vals) : obj

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

@inline delete(obj, o::MaybeOptic) = hasoptic(obj, o.o) ? delete(obj, o.o) : obj


Accessors._shortstring(prev, o::MaybeOptic) = Accessors._shortstring(prev, o.o) * "?" * (
    isnothing(o.default) || ismissing(o.default) || (o.default isa Number && isnan(o.default)) ?
    "" : string(o.default)
)

struct OSomething{OS}
    os::OS
end
Broadcast.broadcastable(o::OSomething) = Ref(o)
osomething(optics...) = OSomething(optics)
@inline (o::OSomething)(obj) = hasoptic(obj, first(o.os)) ? first(o.os)(obj) : (@delete first(o.os))(obj)
@inline (o::OSomething{Tuple{}})(obj) = error("no optic in osomething applicable to $obj")
@inline set(obj, o::OSomething, val) = hasoptic(obj, first(o.os)) ? set(obj, first(o.os), val) : set(obj, (@delete first(o.os)), val)
@inline set(obj, o::OSomething{Tuple{}}, val) = error("no optic in osomething applicable to $obj")

function Base.show(io::IO, os::OSomething)
    compact = get(io, :compact, false)
    print(io, compact ? "some(" : "osomething(")
    for (i, o) in enumerate(os.os)
        i == 1 || print(io, ", ")
        Accessors.show_optic(io, o)
    end
    print(io, ")")
end
Base.show(io::IO, ::MIME"text/plain", optic::OSomething) = show(io, optic)

@inline oget(default::Base.Callable, obj, o) = hasoptic(obj, o) ? o(obj) : default()
@inline oget(obj, o, default=nothing) = hasoptic(obj, o) ? o(obj) : default


@inline set(obj, fa::FixArgsT(get, (Placeholder,Any,Any)), val) =
    haskey(obj, fa.args[2]) ? set(obj, IndexLens((fa.args[2],)), val) : insert(obj, IndexLens((fa.args[2],)), val)
@inline set(obj, fa::FixArgsT(get, (Any,Placeholder,Any)), val) =
    haskey(obj, fa.args[3]) ? set(obj, IndexLens((fa.args[3],)), val) : insert(obj, IndexLens((fa.args[3],)), val)


@inline hasoptic(obj, o::ComposedFunction) = hasoptic(obj, o.inner) && hasoptic(o.inner(obj), o.outer)

@inline hasoptic(obj::AbstractArray, o::IndexLens) = checkbounds(Bool, obj, o.indices...)
@inline hasoptic(obj::Tuple, o::IndexLens) = only(o.indices) in keys(obj)
@inline hasoptic(obj, o::IndexLens) = haskey(obj, only(o.indices))

@inline hasoptic(obj, ::PropertyLens{P}) where {P} = hasproperty(obj, P)

@inline hasoptic(obj, ::typeof(first)) = !isempty(obj)
@inline hasoptic(obj, ::typeof(last)) = !isempty(obj)
@inline hasoptic(obj, ::typeof(only)) = length(obj) == 1

# should override call, set, modify for efficiency?
@inline hasoptic(x::AbstractString, o::Base.Fix1{typeof(parse), Type{T}}) where {T} = !isnothing(tryparse(T, x))
# hasoptic(x::AbstractString, o::Base.Fix2{Type{T}}) where {T <: Union{Date, Time, DateTime}} = # XXX - what to put here?

# fallback definition
# without it: cases when hasoptic throws, but optic actually exists
# with it: cases when hasoptic=true, but optic doesn't exist
@inline hasoptic(obj, o) = !isnothing(obj)


# convenience macros
macro oget(refs...)
    foldr(refs, init=nothing) do ref, curexpr
        obj, optic = parse_obj_optic(ref)
        quote
            optic = $optic
            if $hasoptic($obj, optic)
                optic($obj)
            else
                $curexpr
            end
        end
    end
end

macro osomething(args...)
    return :($osomething($(map(args) do arg
        :($Accessors.@o $arg)
    end...))) |> esc
end

macro maybe(o, default=nothing)
    return :($maybe(($Accessors.@o $o); default=$default)) |> esc
end
