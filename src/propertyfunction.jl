struct PropertyFunction{PNT, F}
    props_nt::PNT
    func::F
end

Base.show(io::IO, pf::PropertyFunction) = print(io, "PropertyFunction(", pf.props_nt, ", ", pf.func, ")")
Base.show(io::IO, ::MIME"text/plain", pf::PropertyFunction) = show(io, pf)

(pf::PropertyFunction{props})(obj) where {props} = pf.func(obj)

needed_properties(::Type{<:PropertyFunction{<:NamedTuple{KS}}}) where {KS} = KS

needed_properties(::ComposedFunction{O,I}) where {I,O} = needed_properties(I)
needed_properties(::Type{PropertyLens{P}}) where {P} = (P,)

needed_properties(::F) where {F} = needed_properties(F)
needed_properties(::Type{F}) where {F} = error("Cannot determine needed properties for function $F")


extract_properties_recursive(x, ::Placeholder) = x
extract_properties_recursive(x::NamedTuple, props_nt::NamedTuple{KS}) where {KS} = NamedTuple{KS}(map(extract_properties_recursive, values(x[KS]), values(props_nt)))
# should work equally well, but hits inference recursion limit:
# extract_properties_recursive(x::NamedTuple, props_nt::NamedTuple{KS}) where {KS} = map(extract_properties_recursive, x[KS], props_nt)
