"""    FlexIx{I}(indices)

For `fi = FlexIx{I}(indices)`:
- indexing `a[fi]` is equivalent to `a[indices]`;
- `@set a[fi] = vs` works even for `vs` of different length than `indices`, shortening/lengthening `a` as needed.
"""
struct FlexIx{I}
    indices::I
end

# shouldn't have any constrains, but this leads to lots of invalidations
# mostly due to getindex(::Type{Any}, vals...)
# Base.getindex(a, i::FlexIx) = getindex(a, i.indices)
# Base.getindex(a::AbstractArray, i::FlexIx) = @invoke getindex(a, i::Any)  # disambiguate

# only make sense for sequentially indexed collections; arrays are handled by to_index, others need getindex:
Base.getindex(a::Tuple, i::FlexIx) = getindex(a, i.indices)
Base.getindex(a::AbstractString, i::FlexIx) = getindex(a, i.indices)

Base.to_index(i::FlexIx) = i.indices


Accessors.setindex(a, v, i::FlexIx) = flex_setindex(a, v, i.indices)
Accessors.setindex(a::AbstractArray, v, i::FlexIx) = flex_setindex(a, v, i.indices)  # disambiguate

flex_setindex(s, v, rng::UnitRange) =
    @views _concat(s[begin:prevind(s, first(rng))], v, s[nextind(s, last(rng)):end])

_concat(a::AbstractArray, b::AbstractArray, c::AbstractArray) = vcat(a, b, c)
_concat(a::AbstractString, b::AbstractString, c::AbstractString) = string(a, b, c)
_concat(a::Tuple, b::Tuple, c::Tuple) = (a..., b..., c...)
