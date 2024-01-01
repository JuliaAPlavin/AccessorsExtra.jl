struct PartsOf end
Broadcast.broadcastable(o::PartsOf) = Ref(o)
struct _PartsOfOptic{O}
    o::O
end
(o::_PartsOfOptic)(obj) = getall(obj, o.o)
set(obj, o::_PartsOfOptic, val) = setall(obj, o.o, val)

Base.:∘(i::PartsOf, o) = _PartsOfOptic(o)
Base.:∘(i::_PartsOfOptic, o) = _PartsOfOptic(i.o ∘ o)
Base.:∘(c::ComposedFunction{<:Any, <:PartsOf}, o) = c.outer ∘ _PartsOfOptic(o)
Base.:∘(c::ComposedFunction{<:Any, <:_PartsOfOptic}, o) = c.outer ∘ _PartsOfOptic(c.inner.o ∘ o)
