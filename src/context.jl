abstract type ContextOptic end

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
 
struct WithContext{I,V}
    i::I
    v::V
end
Base.first(ix::WithContext) = ix.i
Base.last(ix::WithContext) = ix.v
Base.iterate(ix::WithContext, args...) = iterate(ix.i => ix.v, args...)


struct _ContextValOnly{I} <: ContextOptic
    i::I
end
OpticStyle(::Type{<:_ContextValOnly}) = ModifyBased()
modify(f, obj, o::_ContextValOnly) = _unpack_val(f(WithContext(o.i, obj)), o.i)
_unpack_val(x, i) = x
_unpack_val(x::WithContext, i) = (@assert x.i == i; x.v)

modify(f, obj, o::SelfContext) = modify(f, obj, _ContextValOnly(o.f(obj)))

function modify(f, obj, ::Enumerated{Elements})
    i = Ref(1)
    modify(obj, Elements()) do v
        res = modify(f, v, _ContextValOnly(i[]))
        i[] += 1
        res
    end
end

function modify(f, obj, ::Keyed{Elements})
    map(keys(obj), values(obj)) do i, v
        modify(f, v, _ContextValOnly(i))
    end
end

function modify(f, obj::Tuple, ::Keyed{Elements})
    ntuple(length(obj)) do i
        v = obj[i]
        modify(f, v, _ContextValOnly(i))
    end
end

function modify(f, obj::NamedTuple{KS}, ::Keyed{Elements}) where {KS}
    res = map(keys(obj), values(obj)) do i, v
        f(WithContext(i, v))
    end
    all(x -> x isa WithContext, res) ?
        NamedTuple{first.(res)}(last.(res)) :
        NamedTuple{KS}(res)
end


struct KeepContext{O} <: ContextOptic
    o::O
end

export ᵢ
const ᵢ = Val(:ᵢ)
Base.:(*)(o, ::typeof(ᵢ)) = KeepContext(o)

OpticStyle(::Type{KeepContext{O}}) where {O} = ModifyBased() # OpticStyle(O)
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


function modify(f, obj, o::KeepContext)
    modify(f, obj, o.o)
end
function modify(f, obj::WithContext, o::KeepContext)
    if OpticStyle(o.o) isa SetBased
        x = o.o(obj.v)
        fx = f(WithContext(obj.i, x))
        fx isa WithContext ?
            WithContext(fx.i, set(obj.v, o.o, fx.v)) :
            set(obj.v, o.o, fx)
    else
        modify(f, obj.v, _ContextValOnly(obj.i) ∘ o.o)
    end
end
