struct PropertyFunction{PNT, F}
    props_nt::PNT
    func::F
end

Base.show(io::IO, pf::PropertyFunction) = print(io, "PropertyFunction(", pf.props_nt, ", ", pf.func, ")")
Base.show(io::IO, ::MIME"text/plain", pf::PropertyFunction) = show(io, pf)

(pf::PropertyFunction{props})(obj) where {props} = pf.func(obj)

function hasoptic(obj, pf::PropertyFunction)
    isnothing(obj) && return false
    optics = flat_concatoptic(propspec(pf), RecursiveOfType(Placeholder))
    return all(!isnothing, getall(obj, optics))
end

Base.:(!)(pf::PropertyFunction) = PropertyFunction(pf.props_nt, !pf.func)

const PROPFUNCTYPES_ONLYEXTRA = Union{
    PropertyFunction,
    ComposedFunction{<:Any,<:PropertyFunction},
    ContainerOptic,
}
const PROPFUNCTYPES = Union{
    PropertyLens,
    ComposedFunction{<:Any,<:PropertyLens},
    PROPFUNCTYPES_ONLYEXTRA,
}

Base.map(f::PROPFUNCTYPES, x) = map(rawfunc(f), extract_properties_recursive(x, propspec(f)))
Base.map(f::PROPFUNCTYPES, x::AbstractArray) = map(rawfunc(f), extract_properties_recursive(x, propspec(f)))  # disambiguation

# almost same as in Base, but:
# - with PROPFUNCTYPES instead of Function restriction
Base.findall(f::PROPFUNCTYPES, A::AbstractArray) = findall(map(f, A))
# - use map() no matter what the IndexStyle is
Base.filter(f::PROPFUNCTYPES, a::AbstractArray) = a[map(f, a)::AbstractArray{Bool}]
Base.filter(f::PROPFUNCTYPES, a::Array) = a[map(f, a)::AbstractArray{Bool}]  # disambiguation

# all 2nd arg types for disambiguation
for m in methods(Base.Sort._sort!)
    m.sig isa UnionAll && continue
    params = m.sig.parameters
    params[2] === AbstractVector || continue
    Base.Order.Perm <: params[4] || continue
    params[3] === Any && continue

    @eval function Base.Sort._sort!(v::AbstractVector, a::$(params[3]), o::Base.Order.By{<:PROPFUNCTYPES}, kw)
        newo = modify(rawfunc, o, @o _.by)
        return Base.Sort._sort!(extract_properties_recursive(v, propspec(o.by)), a, newo, kw)
    end

    @eval function Base.Sort._sort!(v::AbstractVector, a::$(params[3]), o::Base.Order.Perm{<:Base.Order.By{<:PROPFUNCTYPES}}, kw)
        newo = Base.Order.Perm(
            # @modify(rawfunc, $(o.order).by),
            modify(rawfunc, o.order, @o _.by),
            extract_properties_recursive(o.data, propspec(o.order.by)),
        )
        return Base.Sort._sort!(v, a, newo, kw)
    end
end


rawfunc(f) = f
rawfunc(f::PropertyLens{P}) where {P} = x -> f(x)
rawfunc(f::PropertyFunction) = f.func
rawfunc(f::ComposedFunction) = @modify(rawfunc, decompose(f)[∗])
rawfunc(f::ContainerOptic) = x -> f(x)

propspec(f) = Placeholder()
propspec(f::PropertyLens{P}) where {P} = NamedTuple{(P,)}((Placeholder(),))
propspec(f::PropertyFunction) = f.props_nt
propspec(f::ComposedFunction) = propspec(f.inner)
propspec(f::ComposedFunction{<:Any,PropertyLens{P}}) where {P} = NamedTuple{(P,)}((propspec(f.outer),))
propspec(f::ContainerOptic) = merge(map(f.optics) do o
    propspec(o)
end...)


extract_properties_recursive(x, _) = x
extract_properties_recursive(x, ::Placeholder) = x
extract_properties_recursive(x::NamedTuple, props_nt::NamedTuple{KS}) where {KS} = NamedTuple{KS}(map(extract_properties_recursive, values(x[KS]), values(props_nt)))
# should work equally well, but hits inference recursion limit:
# extract_properties_recursive(x::NamedTuple, props_nt::NamedTuple{KS}) where {KS} = map(extract_properties_recursive, x[KS], props_nt)
