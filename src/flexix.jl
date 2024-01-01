struct FlexIx{I}
    indices::I
end

Base.getindex(a, i::FlexIx) = getindex(a, i.indices)
# disambiguate:
Base.getindex(a::AbstractArray, i::FlexIx) = @invoke getindex(a, i::Any)
Base.to_index(i::FlexIx) = i.indices

Accessors.setindex(a, v, i::FlexIx) = flex_setindex(a, v, i.indices)
# disambiguate:
Accessors.setindex(a::AbstractArray, v, i::FlexIx) = flex_setindex(a, v, i.indices)

flex_setindex(s, v, rng::UnitRange) =
    @views _concat(s[begin:prevind(s, first(rng))], v, s[nextind(s, last(rng)):end])

_concat(a::AbstractArray, b::AbstractArray, c::AbstractArray) = vcat(a, b, c)
_concat(a::AbstractString, b::AbstractString, c::AbstractString) = string(a, b, c)
_concat(a::Tuple, b::Tuple, c::Tuple) = (a..., b..., c...)
