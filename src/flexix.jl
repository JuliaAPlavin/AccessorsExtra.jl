struct FlexIx{I}
    indices::I
end

# shouldn't have any constrains, but this leads to lots of invalidations
# mostly due to getindex(::Type{Any}, vals...)
# Base.getindex(a, i::FlexIx) = getindex(a, i.indices)
# disambiguate if ::Any method, or just support arrays:
Base.getindex(a::AbstractArray, i::FlexIx) = @invoke getindex(a, i::Any)

# only make sense for sequentially indexed collections:
Base.getindex(a::Tuple, i::FlexIx) = getindex(a, i.indices)
Base.getindex(a::AbstractString, i::FlexIx) = getindex(a, i.indices)


Base.to_index(i::FlexIx) = i.indices

Accessors.setindex(a, v, i::FlexIx) = flex_setindex(a, v, i.indices)
# disambiguate:
Accessors.setindex(a::AbstractArray, v, i::FlexIx) = flex_setindex(a, v, i.indices)

flex_setindex(s, v, rng::UnitRange) =
    @views _concat(s[begin:prevind(s, first(rng))], v, s[nextind(s, last(rng)):end])

_concat(a::AbstractArray, b::AbstractArray, c::AbstractArray) = vcat(a, b, c)
_concat(a::AbstractString, b::AbstractString, c::AbstractString) = string(a, b, c)
_concat(a::Tuple, b::Tuple, c::Tuple) = (a..., b..., c...)
