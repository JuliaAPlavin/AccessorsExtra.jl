module DictionariesExt
using Dictionaries
import AccessorsExtra: modify, KVPWrapper, constructorof, Elements

modify(f, obj::KVPWrapper{typeof(keys), <:AbstractDictionary}, ::Elements) =
    constructorof(typeof(obj.obj))(map(f, keys(obj.obj)), values(obj.obj))

modify(f, obj::KVPWrapper{typeof(values), <:AbstractDictionary}, ::Elements) =
    map(f, obj.obj)

modify(f, obj::KVPWrapper{typeof(pairs), <:Dictionary}, ::Elements) =
    dictionary(f(p)::Pair for p in pairs(obj.obj))

end
