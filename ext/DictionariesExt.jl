module DictionariesExt
using Dictionaries
using AccessorsExtra
using AccessorsExtra: KVPWrapper, constructorof, IndexLens
import AccessorsExtra: modify, Accessors

modify(f, obj::KVPWrapper{typeof(keys), <:AbstractDictionary}, ::Elements) =
    constructorof(typeof(obj.obj))(map(f, keys(obj.obj)), values(obj.obj))

modify(f, obj::KVPWrapper{typeof(pairs), <:Dictionary}, ::Elements) =
    dictionary(f(p)::Pair for p in pairs(obj.obj))


# can upstream? Dictionaries or Accessors?
function Accessors.setindex(d::AbstractDictionary{I}, v, k::I) where {I}
    hastok, tok = gettoken(d, k)
    hastok || error("key $k not found in dictionary")
    constructorof(typeof(d))(
        copy(getfield(d, :indices)),
        Accessors.setindex(getfield(d, :values), v, _tok_to_ix(tok)),
    )
end
function Accessors.insert(d::AbstractDictionary, l::IndexLens, v)
    k = only(l.indices)
    newd = _copydict(d)
    hastok, tok = gettoken!(newd, k)
    hastok && error("key $k already exists in dictionary")
    constructorof(typeof(d))(
        getfield(newd, :indices),
        (@set $(getfield(newd, :values))[_tok_to_ix(tok)] = v),
    )
end
Accessors.delete(d::AbstractDictionary, l::IndexLens) = delete!(_copydict(d), only(l.indices))
# cannot just copy(d) or similar(d) because of https://github.com/andyferris/Dictionaries.jl/issues/98
# _copydict(d::AbstractDictionary) = copyto!(similar(d), d)
# instead, we rely on fieldnames (indices and values), and that the dictionary can be reconstructed from them
_copydict(d::AbstractDictionary) = constructorof(typeof(d))(
    copy(getfield(d, :indices)),
    copy(getfield(d, :values))
)

_tok_to_ix(index::Integer) = index
_tok_to_ix((slot, index)) = index

end
