struct PropertyFunction{PNT, F}
    props_nt::PNT
    func::F
    expr::Union{Expr,Nothing}
end

Base.show(io::IO, pf::PropertyFunction) = get(io, :compact, false) ? print(io, pf.expr) : print(io, "(@o ", pf.expr, ")")
Base.show(io::IO, ::MIME"text/plain", pf::PropertyFunction) = show(io, pf)
Base.:(==)(a::PropertyFunction, b::PropertyFunction) = a.expr == b.expr
Base.hash(pf::PropertyFunction, h::UInt) = hash(pf.expr, h)

Accessors._shortstring(prev, o::PropertyFunction) = sprint(show, o; context=:compact => true)

(pf::PropertyFunction{props})(obj) where {props} = pf.func(obj)

function hasoptic(obj, pf::PropertyFunction)
    isnothing(obj) && return false
    optics = flat_concatoptic(propspec(pf), RecursiveOfType(Placeholder))
    return all(!isnothing, getall(obj, optics))
end

Base.:(!)(pf::PropertyFunction) = PropertyFunction(pf.props_nt, !pf.func, :(!$(pf.expr)))

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

# Base.map(f::PROPFUNCTYPES, x) = map(rawfunc(f), extract_properties_recursive(x, propspec(f)))  # causes too many ambiguities...
Base.map(f::PROPFUNCTYPES, x::AbstractArray) = map(rawfunc(f), extract_properties_recursive(x, propspec(f)))

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

    # XXX: wrong! only sorts the properties used in `by=...`, other components are kept as-is!
    # @eval function Base.Sort._sort!(v::AbstractVector, a::$(params[3]), o::Base.Order.By{<:PROPFUNCTYPES}, kw)
    #     newo = modify(rawfunc, o, @o _.by)
    #     return Base.Sort._sort!(extract_properties_recursive(v, propspec(o.by)), a, newo, kw)
    # end

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
propspec(f::ContainerOptic) = rmerge(map(f.optics) do o
    propspec(o)
end...)
propspec(f::Union{⩓,⩔}) = rmerge(propspec(f.f), propspec(f.g))


extract_properties_recursive(x, _) = x
extract_properties_recursive(x, ::Placeholder) = x
extract_properties_recursive(x::NamedTuple, props_nt::NamedTuple{KS}) where {KS} = NamedTuple{KS}(map(extract_properties_recursive, values(x[KS]), values(props_nt)))
# should work equally well, but hits inference recursion limit:
# extract_properties_recursive(x::NamedTuple, props_nt::NamedTuple{KS}) where {KS} = map(extract_properties_recursive, x[KS], props_nt)


rmerge(a, objs...) = foldl(rmerge, objs; init=a)
rmerge(a::NamedTuple, b::NamedTuple) = _mergewith(rmerge, a, b)
rmerge(a::Placeholder, b) = a
rmerge(a, b::Placeholder) = b
rmerge(a::Placeholder, b::Placeholder) = a
rmerge(a, b) =
    if a === b
        a
    else
        error("Don't know how to merge $a and $b")
    end

# https://github.com/JuliaLang/julia/pull/53558
@generated function _mergewith(combine, a::NamedTuple{an}, b::NamedTuple{bn}) where {an, bn}
    names = Base.merge_names(an, bn)
    vals = map(names) do n
        if Base.sym_in(n, an) && Base.sym_in(n, bn)
            :(combine(a.$n, b.$n))
        elseif Base.sym_in(n, an)
            :(a.$n)
        elseif Base.sym_in(n, bn)
            :(b.$n)
        end
    end
    :( NamedTuple{$names}(($(vals...),)) )
end
