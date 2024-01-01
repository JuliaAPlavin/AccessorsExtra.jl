OpticStyle(::Type{<:Base.Fix1{typeof(match)}}) = ModifyBased()
OpticStyle(::Type{<:Base.Fix1{typeof(eachmatch)}}) = ModifyBased()

# same as default; fallback getall() just errors for ModifyBased
getall(obj, o::Base.Fix1{typeof(match)}) = (o(obj),)
getall(obj, o::Base.Fix1{typeof(eachmatch)}) = (o(obj),)


function modify(f, s, o::Base.Fix1{typeof(match)})
    m = match(o.x, s)
    v = f(m)
    repl = if v === m
        s
    elseif v isa AbstractString
        sub = m.match
        rng = (sub.offset+1):(sub.offset+sub.ncodeunits)
        @set s[FlexIx(rng)] = v
    else
        error("Expected AbstractString or $m, got $v")
    end
end

getall(obj::Base.RegexMatchIterator, ::Elements) = obj

# special wrapper type, can only be modify'ed with Elements()
struct EachMatchWrapper
    mi::Base.RegexMatchIterator
end

function modify(f, s::AbstractString, o::Base.Fix1{typeof(eachmatch)})
    replacements = f(EachMatchWrapper(o(s)))
    @assert issorted(replacements, by=r -> first(first(r)))
    foldl(reverse(replacements); init=s) do s, (rng, v)
        @set s[FlexIx(rng)] = v
    end
end

function modify(f, obj::EachMatchWrapper, ::Elements)
    replacements = map(obj.mi) do m
        sub = m.match
        rng = (sub.offset+1):(sub.offset+sub.ncodeunits)
        v = f(m)
        repl = if v === m
            m.match
        elseif v isa AbstractString
            v
        else
            error("Expected AbstractString or $m, got $v")
        end
        rng => repl::AbstractString
    end
end

function setall(obj::Base.RegexMatchIterator, ::Elements, vs)
    eltype(vs) <: AbstractString || error("Only strings are supported for RegexMatchIterator |> Elements()")
    return vs
end

function setall(obj::AbstractString, o::Base.Fix1{typeof(eachmatch)}, vs::Tuple{Any})
    replacements = map(eachmatch(o.x, obj), only(vs)) do m, x
        sub = m.match
        rng = (sub.offset+1):(sub.offset+sub.ncodeunits)
        rng => x::AbstractString
    end
    @assert issorted(replacements, by=r -> first(first(r)))
    foldl(reverse(replacements); init=obj) do s, (rng, v)
        @set s[FlexIx(rng)] = v
    end
end

set(m::RegexMatch, o::IndexLens, v) = _set_regexmatch(m, o, v)
set(m::RegexMatch, o::PropertyLens, v) = _set_regexmatch(m, o, v)
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

function modify(f, m::RegexMatch, ::Elements)
    foldl(reverse(m.captures); init=m.match) do s, sub
        v = f(sub)
        rng = ((sub.offset+1):(sub.offset+sub.ncodeunits)) .- m.match.offset
        @set s[FlexIx(rng)] = v
    end
end

function modify(f, m::RegexMatch, ::Keyed{Elements})
    foldl(reverse(keys(m)); init=m.match) do s, k
        sub = m[k]
        v = modify(f, sub, _ContextValOnly(k))
        rng = ((sub.offset+1):(sub.offset+sub.ncodeunits)) .- m.match.offset
        @set s[FlexIx(rng)] = v
    end
end
