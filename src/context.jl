abstract type ContextOptic end
Broadcast.broadcastable(o::ContextOptic) = Ref(o)
hascontext(::ContextOptic) = true

struct ValWithContext{C,V}
    ctx::C
    v::V

    function ValWithContext(ctx, v)
        @assert !(v isa ValWithContext)
        new{typeof(ctx),typeof(v)}(ctx, v)
    end
end
ValWithContext(ctx, v::ValWithContext) = ValWithContext(MultiContext(ctx, v.ctx), v.v)
Base.first(ix::ValWithContext) = ix.ctx
Base.last(ix::ValWithContext) = ix.v
Base.iterate(ix::ValWithContext, args...) = iterate(ix.ctx => ix.v, args...)
Base.show(io::IO, ix::ValWithContext) = print(io, ix.ctx, " ⇒ ", ix.v)
hascontext(::ValWithContext) = true
@accessor stripcontext(ix::ValWithContext) = stripcontext(ix.v)

struct MultiContext{CS}
    contexts::CS

    function MultiContext(ctxs...)
        fullctxs = _reduce_concat(map(_contexts, ctxs))
        new{typeof(fullctxs)}(fullctxs)
    end
end
_contexts(ctx) = (ctx,)
_contexts(ctx::MultiContext) = ctx.contexts
Base.getindex(ctx::MultiContext, i) = ctx.contexts[i]
Base.iterate(ctx::MultiContext, args...) = iterate(ctx.contexts, args...)


struct _ContextValOnly{C} <: ContextOptic
    ctx::C
end
stripcontext(o::_ContextValOnly) = identity
(o::_ContextValOnly)(obj) = ValWithContext(o.ctx, obj)
set(obj, o::_ContextValOnly, v) = _unpack_val(v, o(obj).ctx)
_unpack_val(x, i) = x
_unpack_val(x::ValWithContext, i) = (@assert x.ctx == i; x.v)


struct Keyed{O} <: ContextOptic
    o::O
end
@accessor stripcontext(o::Keyed) = stripcontext(o.o)
OpticStyle(::Type{Keyed{O}}) where {O} = ModifyBased()
Base.show(io::IO, co::Keyed) = print(io, "keyed(", co.o, ")")
Accessors._shortstring(prev, o::Keyed) = "$prev |> keyed($(o.o))"

keyed(o) = Keyed(o)
keyed(o::PropertyLens{p}) where {p} = _ContextValOnly(p) ∘ o

struct Enumerated{O} <: ContextOptic
    o::O
end
@accessor stripcontext(o::Enumerated) = stripcontext(o.o)
OpticStyle(::Type{Enumerated{O}}) where {O} = ModifyBased()
Base.show(io::IO, co::Enumerated) = print(io, "enumerated(", co.o, ")")
Accessors._shortstring(prev, o::Enumerated) = "$prev |> enumerated($(o.o))"

enumerated(o) = Enumerated(o)

struct SelfContext{F} <: ContextOptic
    f::F
end
stripcontext(o::SelfContext) = identity
set(o::SelfContext, ::typeof(stripcontext), v::typeof(identity)) = o
set(o::SelfContext, ::typeof(stripcontext), v) = error("Not implemented")
OpticStyle(::Type{<:SelfContext}) = ModifyBased()
Base.show(io::IO, co::SelfContext) = print(io, "selfcontext(", co.f, ")")
Accessors._shortstring(prev, o::SelfContext) = "$prev |> selfcontext($(o.f))"
selfcontext(f=identity) = SelfContext(f)

modify(f, obj, o::SelfContext) = modify(f, obj, _ContextValOnly(o.f(obj)))
(o::SelfContext)(obj) = ValWithContext(o.f(obj), obj)
# same as default; fallback getall() just errors for ModifyBased
getall(obj, o::SelfContext) = (o(obj),)

getall(obj, ::Enumerated{Elements}) = map(ValWithContext, _1indices(obj), values(obj))
getall(obj, o::Enumerated) = map(ValWithContext, Iterators.countfrom(), getall(obj, o.o))
getall(obj, ::Keyed{Elements}) = map(ValWithContext, _keys(obj), values(obj))
getall(obj, ::Keyed{Properties}) = getall(getproperties(obj), keyed(Elements()))

# needs to call modify(obj, Elements()) and not map(...): only the former works for regex optics
function modify(f, obj, o::Enumerated)
    i = Ref(1)
    modify(obj, o.o) do v
        res = modify(f, v, _ContextValOnly(i[]))
        i[] += 1
        res
    end
end

modify(f, obj, ::Keyed{Elements}) =
    map(_keys(obj), values(obj)) do i, v
        modify(f, v, _ContextValOnly(i))
    end

modify(f, obj::NamedTuple{KS}, ::Keyed{Elements}) where {KS} = @p let
    map(keys(obj), values(obj)) do i, v
        f(ValWithContext(i, v))
    end
    all(x -> x isa ValWithContext, __) ?
        NamedTuple{first.(__)}(last.(__)) :
        NamedTuple{KS}(__)
end

modify(f, obj, ::Keyed{Properties}) = modify(f, obj, keyed(Elements()) ∘ getproperties)

struct KeepContext{O} <: ContextOptic
    o::O
end
@accessor stripcontext(o::KeepContext) = stripcontext(o.o)

export ᵢ
const ᵢ = Val(:ᵢ)
Base.:(*)(o, ::typeof(ᵢ)) = KeepContext(o)

OpticStyle(::Type{KeepContext{O}}) where {O} = OpticStyle(O)
Base.show(io::IO, co::KeepContext) = print(io, "(ᵢ", co.o, ")ᵢ")

for T in [
        ComposedFunction{<:ContextOptic, <:ContextOptic},
        ComposedFunction{<:ContextOptic, <:Any},
        ComposedFunction{<:Any, <:ContextOptic},
        ContextOptic,
    ]
    @eval Base.:∘(o::KeepContext, c::$T) = ComposedFunction(o, c)
    @eval Base.:∘(o::_ContextValOnly, c::$T) = ComposedFunction(o, c)
    @eval Base.:∘(o, c::$T) = KeepContext(o) ∘ c
end


(o::KeepContext)(obj) = o.o(obj)
(o::KeepContext)(obj::ValWithContext) = @modify(o.o, obj.v)
getall(obj, o::KeepContext) = getall(obj, o.o)
getall(obj::ValWithContext, o::KeepContext) = map(x -> @set(obj.v = x), getall(obj.v, o.o))


modify(f, obj, o::KeepContext) = modify(f, obj, o.o)
modify(f, obj::ValWithContext, o::KeepContext) =
    if OpticStyle(o.o) isa SetBased
        fx = f(o(obj))
        @assert !(fx isa ValWithContext)
        set(obj.v, o.o, fx)
        # fx = f(o(obj))
        # fx isa ValWithContext ?
        #     ValWithContext(fx.ctx, set(obj.v, o.o, fx.v)) :
        #     set(obj.v, o.o, fx)
    else
        modify(f, obj.v, _ContextValOnly(obj.ctx) ∘ o.o)
    end



stripcontext(o::ComposedFunction) = @modify(stripcontext, decompose(o)[∗])
stripcontext(o::ConcatOptics) = @modify(stripcontext, o.optics[∗])
stripcontext(o) = o

set(o::ComposedFunction, ::typeof(stripcontext), v) = hascontext(o) || hascontext(v) ? error("Not implemented") : v
set(o::ConcatOptics, ::typeof(stripcontext), v) = error("Not implemented")
set(o, ::typeof(stripcontext), v) = v

hascontext(o::ComposedFunction) = any(hascontext, decompose(o))
function hascontext(o::ConcatOptics)
    @assert allequal(map(hascontext, o.optics))
    return hascontext(first(o.optics))
end
hascontext(o) = false


# helpers:
# should be the same kind of type as values(obj) if possible, eg AbstractVector, Tuple
# so that map(keys, values) returns the same kind of type
_keys(obj) = keys(obj)
_keys(::NTuple{N,Any}) where {N} = ntuple(identity, N)
_1indices(obj) = first.(enumerate(obj))  # inefficient?
_1indices(obj::AbstractArray) = 1:length(obj)
_1indices(::NTuple{N,Any}) where {N} = ntuple(identity, N)
_1indices(::NamedTuple{KS}) where {KS} = ntuple(identity, length(KS))
