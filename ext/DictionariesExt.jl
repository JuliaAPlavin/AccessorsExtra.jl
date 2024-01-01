module DictionariesExt
using Dictionaries
import AccessorsExtra: modify, KVPWrapper, constructorof, Elements, IndexLens, Accessors

modify(f, obj::KVPWrapper{typeof(keys), <:AbstractDictionary}, ::Elements) =
    constructorof(typeof(obj.obj))(map(f, keys(obj.obj)), values(obj.obj))

modify(f, obj::KVPWrapper{typeof(values), <:AbstractDictionary}, ::Elements) =
    map(f, obj.obj)

modify(f, obj::KVPWrapper{typeof(pairs), <:Dictionary}, ::Elements) =
    dictionary(f(p)::Pair for p in pairs(obj.obj))


Accessors.setindex(d0::AbstractDictionary, v, k) = merge(d0, Dictionary([k], [v]))
Accessors.insert(obj::AbstractDictionary, l::IndexLens, val) = Accessors.setindex(obj, val, only(l.indices))
function Accessors.delete(obj::AbstractDictionary, l::IndexLens)
    # cannot use delete! on copy because of https://github.com/andyferris/Dictionaries.jl/issues/98
    # delete!(copy(obj), only(l.indices))
    out = Dictionary(copy(obj.indices), copy(obj.values))
    delete!(out, only(l.indices))
    return out
end

end
