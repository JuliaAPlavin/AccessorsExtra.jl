Accessors.OpticStyle(::Type{<:Base.Fix1{typeof(match)}}) = Accessors.ModifyBased()

function Accessors.modify(f, s, o::Base.Fix1{typeof(match)})
    m = match(o.x, s)
    v = f(m)
    repl = if v isa AbstractString
        sub = m.match
        rng = (sub.offset+1):(sub.offset+sub.ncodeunits)
        @set s[FlexIx(rng)] = v
    else
        @assert v === m
        return s
    end
end


struct EachmatchElements
    r::Regex
end
Accessors.OpticStyle(::Type{<:EachmatchElements}) = Accessors.ModifyBased()

Base.:∘(i::Elements, o::Base.Fix1{typeof(eachmatch)}) = EachmatchElements(o.x)
Base.:∘(c::ComposedFunction{<:Any, <:Elements}, o::Base.Fix1{typeof(eachmatch)}) = c.outer ∘ EachmatchElements(o.x)

Accessors.getall(s::AbstractString, o::EachmatchElements) = eachmatch(o.r, s)

function Accessors.modify(f, s::AbstractString, o::EachmatchElements)
    replacements = map(eachmatch(o.r, s)) do m
        sub = m.match
        rng = (sub.offset+1):(sub.offset+sub.ncodeunits)
        x = f(m)
        repl = if x isa AbstractString
            x
        else
            @assert x === m
            m.match
        end
        rng => repl::AbstractString
    end
    @assert issorted(replacements, by=r -> first(first(r)))
    foldl(reverse(replacements); init=s) do s, (rng, v)
        @set s[FlexIx(rng)] = v
    end
end

function Accessors.setall(s::AbstractString, o::EachmatchElements, v)
    replacements = map(eachmatch(o.r, s), v) do m, x
        sub = m.match
        rng = (sub.offset+1):(sub.offset+sub.ncodeunits)
        rng => x::AbstractString
    end
    @assert issorted(replacements, by=r -> first(first(r)))
    foldl(reverse(replacements); init=s) do s, (rng, v)
        @set s[FlexIx(rng)] = v
    end
end

Accessors.set(m::RegexMatch, o::IndexLens, v) = _set_regexmatch(m, o, v)
Accessors.set(m::RegexMatch, o::PropertyLens, v) = _set_regexmatch(m, o, v)
function _set_regexmatch(m::RegexMatch, o::Union{IndexLens,PropertyLens}, v::AbstractString)
    sub = o(m)
    rng = ((sub.offset+1):(sub.offset+sub.ncodeunits)) .- m.match.offset
    s = m.match
    @set s[FlexIx(rng)] = v
end

function _set_regexmatch(m::RegexMatch, o::Union{IndexLens,PropertyLens}, v::Nothing)
    sub = o(m)
    @assert isnothing(sub)
    m
end

function Accessors.modify(f, m::RegexMatch, ::Elements)
    foldl(reverse(m.captures); init=m.match) do s, sub
        v = f(sub)
        rng = ((sub.offset+1):(sub.offset+sub.ncodeunits)) .- m.match.offset
        @set s[FlexIx(rng)] = v
    end
end
