struct PropertyFunction{PNT, F}
    props_nt::PNT
    func::F
end

Base.show(io::IO, pf::PropertyFunction) = print(io, "PropertyFunction(", pf.props_nt, ", ", pf.func, ")")
Base.show(io::IO, ::MIME"text/plain", pf::PropertyFunction) = show(io, pf)

(pf::PropertyFunction{props})(obj) where {props} = pf.func(obj)

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
Base.map(f::PROPFUNCTYPES, x::AbstractArray) = map(rawfunc(f), extract_properties_recursive(x, propspec(f)))

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
