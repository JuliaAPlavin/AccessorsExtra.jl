module AccessorsExtra

using Reexport
@reexport using Accessors
using CompositionsBase
import Accessors: set, modify, delete, insert, getall, setall, OpticStyle, SetBased, ModifyBased
using DataPipes
@reexport using ConstructionBase
using InverseFunctions
using LinearAlgebra: norm
using Accessors: MacroTools

export
    @o,
    ∗, ∗ₚ, PartsOf,
    ⩓, ⩔,
    concat, ++, @optics, @optic₊,
    @replace, @push, @pushfirst, @pop, @popfirst,
    construct, @construct,
    RecursiveOfType,
    keyed, enumerated, selfcontext, stripcontext, hascontext,
    maybe, osomething, oget, hasoptic,
    modifying, onget, onset, ongetset,
    FlexIx,
    get_steps, logged


include("overrides.jl")
include("keyvalues.jl")
include("flexix.jl")
include("fixargs.jl")
include("concatoptic.jl")
include("recursive.jl")
include("context.jl")
include("modifymany.jl")
include("maybe.jl")
include("partsof.jl")
include("funclenses.jl")
include("regex.jl")
include("replace.jl")
include("moremacros.jl")
include("construct.jl")
include("bystep.jl")
include("testing.jl")

const var"@o" = var"@optic"


Base.@propagate_inbounds set(obj, lens::Base.Fix2{typeof(view)}, val) = setindex!(obj, val, lens.x)
Base.@propagate_inbounds set(obj, lens::Base.Fix2{typeof(view), <:Integer}, val::AbstractArray{<:Any, 0}) = setindex!(obj, only(val), lens.x)


# set getfields(): see https://github.com/JuliaObjects/Accessors.jl/pull/57
set(obj, o::typeof(getfields), val) = constructorof(typeof(obj))(val...)
set(obj, o::Base.Fix2{typeof(getfield)}, val) = @set getfields(obj)[o.x] = val

# inverse getindex
# XXX: should only be defined for a separate type, something like Bijection
# otherwise not really an inverse
InverseFunctions.inverse(f::Base.Fix1{typeof(getindex)}) = Base.Fix2(findfirst, f.x) ∘ isequal
InverseFunctions.inverse(f::ComposedFunction{<:Base.Fix2{typeof(findfirst)}, typeof(isequal)}) = Base.Fix1(getindex, f.outer.x)

# https://github.com/JuliaObjects/Accessors.jl/pull/103
function set(obj, f::Base.Fix1{typeof(getindex)}, val)
    ix = findfirst(isequal(val), f.x)
    ix === nothing && throw(ArgumentError("value $val not found in $(f.x)"))
    return ix
end

# shortcuts
const ∗ = Elements()
const ∗ₚ = Properties()
# some piracy:
Accessors.IndexLens(::Tuple{Elements}) = Elements()
Accessors.IndexLens(::Tuple{Properties}) = Properties()
Accessors._shortstring(prev, o::Elements) = "$prev[∗]"
Accessors._shortstring(prev, o::Properties) = "$prev[∗ₚ]"
Base.show(io::IO, ::Elements) = print(io, "∗")
Base.show(io::IO, ::Properties) = print(io, "∗ₚ")
Base.show(io::IO, ::MIME"text/plain", optic::Union{Elements,Properties}) = show(io, optic)

# like in Accessors, but for Elements and Properties
Base.show(io::IO, optic::ComposedFunction{<:Any, <:Union{Elements,Properties}}) = Accessors.show_optic(io, optic)
# resolve method ambiguity with Base:
Base.show(io::IO, optic::ComposedFunction{typeof(!), <:Union{Elements,Properties}}) = Accessors.show_optic(io, optic)


Accessors._shortstring(prev, o::Base.Splat) = "$(o.f)($prev...)"


struct ⩓{F,G}
    f::F
    g::G
end
(c::⩓)(x) = c.f(x) && c.g(x)

struct ⩔{F,G}
    f::F
    g::G
end
(c::⩔)(x) = c.f(x) || c.g(x)


# unambiguous for unitranges, but tension with general array @set first(x)...
# piracy
set(r::AbstractUnitRange, ::typeof(first), x) = x:last(r)
set(r::AbstractUnitRange, ::typeof(last),  x) = first(r):x
set(r::Base.OneTo, ::typeof(last), x) = Base.OneTo(x)
set(r::Base.OneTo, ::typeof(length), x) = Base.OneTo(x)


struct ConstrainedLens{O,MO}
    o::O
    mo::MO
end

modifying(mo) = o -> ConstrainedLens(o, mo)

(c::ConstrainedLens)(x) = c.o(x)
set(obj::Complex, c::ConstrainedLens{typeof(angle),typeof(real)}, val) = set(obj, c.mo, imag(obj)/tan(val))
set(obj::Complex, c::ConstrainedLens{typeof(angle),typeof(imag)}, val) = set(obj, c.mo, real(obj)*tan(val))


struct onset{F}
    f::F
end
@inline (o::onset)(x) = x
@inline set(obj, o::onset, val) = o.f(val)

struct onget{F}
    f::F
end
@inline (o::onget)(x) = o.f(x)
@inline set(obj, o::onget, val) = val

ongetset(f) = onget(f) ∘ onset(f)


# should probably try to upstream:
set(obj, o::Base.Fix1{typeof(in)}, val::Bool) = val ? union(obj, (o.x,)) : setdiff(obj, (o.x,))
set(obj, ::typeof(splat(atan)), val) = @set Tuple(obj) = norm(obj) .* (sin(val), cos(val))

end
