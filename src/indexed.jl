struct IXed{O}
    o::O
end
OpticStyle(::Type{IXed{O}}) where {O} = ModifyBased()
Base.show(io::IO, co::IXed) = print(io, "ixed(", co.o, ")")

keyed(o) = IXed(o)
keyed(o::PropertyLens{p}) where {p} = _IndexedValOnly(p) ∘ o

struct Enumerated{O}
    o::O
end
OpticStyle(::Type{Enumerated{O}}) where {O} = ModifyBased()
Base.show(io::IO, co::Enumerated) = print(io, "ixed(", co.o, ")")

enumerated(o) = Enumerated(o)

struct SelfIndexed{F}
    f::F
end
OpticStyle(::Type{<:SelfIndexed}) = ModifyBased()
Base.show(io::IO, co::SelfIndexed) = print(io, "ixed(", co.f, ")")
selfindexed(f=identity) = SelfIndexed(f)
 
struct WithIndex
    i
    v
end
Base.first(ix::WithIndex) = ix.i
Base.last(ix::WithIndex) = ix.v
Base.iterate(ix::WithIndex, args...) = iterate(ix.i => ix.v, args...)


struct _IndexedValOnly{I}
    i::I
end
OpticStyle(::Type{<:_IndexedValOnly}) = ModifyBased()
modify(f, obj, o::_IndexedValOnly) = _unpack_val(f(WithIndex(o.i, obj)), o.i)
_unpack_val(x, i) = x
_unpack_val(x::WithIndex, i) = (@assert x.i == i; x.v)

modify(f, obj, o::SelfIndexed) = modify(f, obj, _IndexedValOnly(o.f(obj)))

function modify(f, obj, ::Enumerated{Elements})
    i = Ref(1)
    modify(obj, Elements()) do v
        res = modify(f, v, _IndexedValOnly(i[]))
        i[] += 1
        res
    end
end

function modify(f, obj, ::IXed{Elements})
    map(keys(obj), values(obj)) do i, v
        modify(f, v, _IndexedValOnly(i))
    end
end

function modify(f, obj::Tuple, ::IXed{Elements})
    ntuple(length(obj)) do i
        v = obj[i]
        modify(f, v, _IndexedValOnly(i))
    end
end

function modify(f, obj::NamedTuple{KS}, ::IXed{Elements}) where {KS}
    res = map(keys(obj), values(obj)) do i, v
        f(WithIndex(i, v))
    end
    all(x -> x isa WithIndex, res) ?
        NamedTuple{first.(res)}(last.(res)) :
        NamedTuple{KS}(res)
end


struct KeepindexOptic{O}
    o::O
end

export ᵢ
const ᵢ = Val(:ᵢ)
Base.:(*)(o, ::typeof(ᵢ)) = KeepindexOptic(o)
Base.:(*)(o::ComposedFunction, ::typeof(ᵢ)) = @modify(o -> o * ᵢ, deopcompose(o)[∗])

OpticStyle(::Type{KeepindexOptic{O}}) where {O} = ModifyBased() # OpticStyle(O)
Base.show(io::IO, co::KeepindexOptic) = print(io, "", co.o, "ᵢ")

function modify(f, obj, o::KeepindexOptic)
    modify(f, obj, o.o)
end
function modify(f, obj::WithIndex, o::KeepindexOptic)
    if OpticStyle(o.o) isa SetBased
        x = o.o(obj.v)
        fx = f(WithIndex(obj.i, x))
        fx isa WithIndex ?
            WithIndex(fx.i, set(obj.v, o.o, fx.v)) :
            set(obj.v, o.o, fx)
    else
        modify(f, obj.v, _IndexedValOnly(obj.i) ∘ o.o)
    end
end
