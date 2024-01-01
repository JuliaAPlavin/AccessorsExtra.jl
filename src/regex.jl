struct EachmatchElements
    r::Regex
end
Accessors.OpticStyle(::Type{<:EachmatchElements}) = Accessors.ModifyBased()

struct EachmatchLens{I}
    i::I
    r::Regex
end
Accessors.OpticStyle(::Type{<:EachmatchLens}) = Accessors.ModifyBased()

Base.:∘(i::Elements, o::Base.Fix1{typeof(eachmatch)}) = EachmatchElements(o.x)
Base.:∘(c::ComposedFunction{<:Any, <:Elements}, o::Base.Fix1{typeof(eachmatch)}) = c.outer ∘ EachmatchElements(o.x)

Base.:∘(i::IndexLens, o::EachmatchElements) = EachmatchLens(i, o.r)
Base.:∘(c::ComposedFunction{<:Any, <:IndexLens}, o::EachmatchElements) = c.outer ∘ EachmatchLens(c.inner, o.r)
Base.:∘(i::PropertyLens, o::EachmatchElements) = EachmatchLens(i, o.r)
Base.:∘(c::ComposedFunction{<:Any, <:PropertyLens}, o::EachmatchElements) = c.outer ∘ EachmatchLens(c.inner, o.r)

function Accessors.getall(s::AbstractString, o::EachmatchElements)
    eachmatch(o.r, s)
end

function Accessors.modify(f, s::AbstractString, o::EachmatchElements)
    setall(s, o, map(f, getall(s, o)))
end

function Accessors.setall(s::AbstractString, o::EachmatchElements, v)
    replacements = map(eachmatch(o.r, s), v) do m, x
        sub = m.match
        rng = (sub.offset+1):(sub.offset+sub.ncodeunits)
        rng => x::AbstractString
    end
    @assert issorted(replacements, by=r -> first(first(r)))
    foldl(reverse(replacements); init=s) do s, (rng, v)
        @views s[begin:prevind(s, first(rng))] * v * s[nextind(s, last(rng)):end]
    end
end

function Accessors.getall(s::AbstractString, o::EachmatchLens)
    map(o.i, eachmatch(o.r, s))
end

function Accessors.modify(f, s::AbstractString, o::EachmatchLens)
    setall(s, o, map(f, getall(s, o)))
end

function Accessors.setall(s::AbstractString, o::EachmatchLens, v)
    replacements = map(eachmatch(o.r, s), v) do m, x
        sub = o.i(m)
        rng = (sub.offset+1):(sub.offset+sub.ncodeunits)
        rng => x
    end
    @assert issorted(replacements, by=r -> first(first(r)))
    foldl(reverse(replacements); init=s) do s, (rng, v)
        @views s[begin:prevind(s, first(rng))] * v * s[nextind(s, last(rng)):end]
    end
end
