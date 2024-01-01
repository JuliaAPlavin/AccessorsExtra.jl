struct FlexIx{I}
    indices::I
end

Accessors.setindex(a, v, i::FlexIx) = flex_setindex(a, v, i.indices)

flex_setindex(s::AbstractString, v::AbstractString, rng::UnitRange) =
    @views s[begin:prevind(s, first(rng))] * v * s[nextind(s, last(rng)):end]
