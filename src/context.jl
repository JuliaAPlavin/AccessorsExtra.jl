abstract type ContextOptic end
Broadcast.broadcastable(o::ContextOptic) = Ref(o)

struct ValWithContext{I,V}
    i::I
    v::V
end
Base.first(ix::ValWithContext) = ix.i
Base.last(ix::ValWithContext) = ix.v
Base.iterate(ix::ValWithContext, args...) = iterate(ix.i => ix.v, args...)
Base.show(io::IO, ix::ValWithContext) = print(io, ix.i, " ⇒ ", ix.v)


struct _ContextValOnly{I} <: ContextOptic
    i::I
end
OpticStyle(::Type{<:_ContextValOnly}) = ModifyBased()
modify(f, obj, o::_ContextValOnly) = _unpack_val(f(ValWithContext(o.i, obj)), o.i)
_unpack_val(x, i) = x
_unpack_val(x::ValWithContext, i) = (@assert x.i == i; x.v)


struct Keyed{O} <: ContextOptic
    o::O
end
OpticStyle(::Type{Keyed{O}}) where {O} = ModifyBased()
Base.show(io::IO, co::Keyed) = print(io, "keyed(", co.o, ")")

keyed(o) = Keyed(o)
keyed(o::PropertyLens{p}) where {p} = _ContextValOnly(p) ∘ o

struct Enumerated{O} <: ContextOptic
    o::O
end
OpticStyle(::Type{Enumerated{O}}) where {O} = ModifyBased()
Base.show(io::IO, co::Enumerated) = print(io, "enumerated(", co.o, ")")

enumerated(o) = Enumerated(o)

struct SelfContext{F} <: ContextOptic
    f::F
end
OpticStyle(::Type{<:SelfContext}) = ModifyBased()
Base.show(io::IO, co::SelfContext) = print(io, "selfcontext(", co.f, ")")
selfcontext(f=identity) = SelfContext(f)

modify(f, obj, o::SelfContext) = modify(f, obj, _ContextValOnly(o.f(obj)))
(o::SelfContext)(obj) = ValWithContext(o.f(obj), obj)
# same as default; fallback getall() just errors for ModifyBased
getall(obj, o::SelfContext) = (o(obj),)

getall(obj, ::Enumerated{Elements}) =
    map(enumerate(obj)) do (i, v)
        ValWithContext(i, v)
    end

getall(obj, ::Keyed{Elements}) =
    map(_keys(obj), values(obj)) do i, v
        ValWithContext(i, v)
    end

function modify(f, obj, ::Enumerated{Elements})
    i = Ref(1)
    modify(obj, Elements()) do v
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


struct KeepContext{O} <: ContextOptic
    o::O
end

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
    @eval Base.:∘(o, c::$T) = KeepContext(o) ∘ c
end

(o::KeepContext)(obj) = o.o(obj)
(o::KeepContext)(obj::ValWithContext) = @modify(o.o, obj.v)
getall(obj, o::KeepContext) = getall(obj, o.o)
getall(obj::ValWithContext, o::KeepContext) = map(x -> @set(obj.v = x), getall(obj.v, o.o))

modify(f, obj, o::KeepContext) = modify(f, obj, o.o)
modify(f, obj::ValWithContext, o::KeepContext) =
    if OpticStyle(o.o) isa SetBased
        x = o.o(obj.v)
        fx = f(ValWithContext(obj.i, x))
        fx isa ValWithContext ?
            ValWithContext(fx.i, set(obj.v, o.o, fx.v)) :
            set(obj.v, o.o, fx)
    else
        modify(f, obj.v, _ContextValOnly(obj.i) ∘ o.o)
    end


# helpers:
# should be the same kind of type as values(obj) if possible, eg AbstractVector, Tuple
# so that map(keys, values) returns the same kind of type
_keys(obj) = keys(obj)
_keys(::NTuple{N,Any}) where {N} = ntuple(identity, N)
