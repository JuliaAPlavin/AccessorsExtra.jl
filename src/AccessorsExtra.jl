module AccessorsExtra

using Reexport
@reexport using Accessors
using Accessors: compose, opcompose, decompose, deopcompose
import Accessors: set, modify, delete, insert, getall, setall, OpticStyle, SetBased, ModifyBased
using DataPipes
using ConstructionBase
using InverseFunctions
using Requires
using Accessors: MacroTools

export
    ∗, ∗ₚ, PartsOf,
    ⩓, ⩔,
    concat, ++, @optics, @optic₊,
    @replace,
    assemble, @assemble,
    unrecurcize, RecursiveOfType,
    keyed, enumerated, selfcontext,
    maybe, osomething, hasoptic,
    FlexIx,
    get_steps, logged,
    OptArgs, OptCons, OptProblemSpec, solobj


include("setindex.jl")
include("keyvalues.jl")
include("flexix.jl")
include("concatoptic.jl")
include("alongside.jl")
include("recursive.jl")
include("context.jl")
include("maybe.jl")
include("partsof.jl")
include("funclenses.jl")
include("regex.jl")
include("replace.jl")
include("assemble.jl")
include("bystep.jl")
include("optimization.jl")
include("testing.jl")


function __init__()
    # https://github.com/PainterQubits/Unitful.jl/pull/622
    @require Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d" begin
        using .Unitful

        InverseFunctions.inverse(f::Base.Fix1{typeof(ustrip)}) = Base.Fix1(*, true*f.x)
    end
end


# https://github.com/JuliaFunctional/CompositionsBase.jl/pull/12
InverseFunctions.inverse(::typeof(deopcompose)) = Base.splat(opcompose)
InverseFunctions.inverse(::typeof(Base.splat(opcompose))) = deopcompose
InverseFunctions.inverse(::typeof(decompose)) = Base.splat(compose)
InverseFunctions.inverse(::typeof(Base.splat(compose))) = decompose


# Tuples, arrays: upstream to Accessors?
set(obj::Tuple, ::Type{Tuple}, val::Tuple) = val
set(obj::NamedTuple{KS}, ::Type{Tuple}, val::Tuple) where {KS} = NamedTuple{KS}(val)

set(obj, o::Base.Fix1{typeof(map)}, val) = map((ob, v) -> set(ob, o.x, v), obj, val)
set(obj, o::Base.Fix1{typeof(filter)}, val) = @set obj[findall(o.x, obj)] = val
modify(f, obj, o::Base.Fix1{typeof(filter)}) = @modify(f, obj[findall(o.x, obj)])
set(obj, ::typeof(sort), val) = @set obj[sortperm(obj)] = val

set(obj, ::typeof(getproperties), val::NamedTuple) = (@assert keys(val) == keys(getproperties(obj)); setproperties(obj, val))


Base.@propagate_inbounds set(obj, lens::Base.Fix2{typeof(view)}, val) = setindex!(obj, val, lens.x)
Base.@propagate_inbounds set(obj, lens::Base.Fix2{typeof(view), <:Integer}, val::AbstractArray{<:Any, 0}) = setindex!(obj, only(val), lens.x)


# set getfields(): see https://github.com/JuliaObjects/Accessors.jl/pull/57
set(obj, o::typeof(getfields), val) = constructorof(typeof(obj))(val...)
set(obj, o::Base.Fix2{typeof(getfield)}, val) = @set getfields(obj)[o.x] = val

# inverse getindex
InverseFunctions.inverse(f::Base.Fix1{typeof(getindex)}) = Base.Fix2(findfirst, f.x) ∘ isequal
InverseFunctions.inverse(f::ComposedFunction{<:Base.Fix2{typeof(findfirst)}, typeof(isequal)}) = Base.Fix1(getindex, f.outer.x)

# shortcuts, no piracy
const ∗ = Elements()
const ∗ₚ = Properties()

Accessors.IndexLens(::Tuple{typeof(∗)}) = Elements()
Accessors._shortstring(prev, o::Elements) = "$prev[∗]"

Accessors.IndexLens(::Tuple{typeof(∗ₚ)}) = Properties()
Accessors._shortstring(prev, o::Properties) = "$prev[∗ₚ]"


delete(obj, o::If) = error("`delete(obj, ::If)` not supported, try using `filter` as an optic instead")
delete(obj, o::Base.Fix1{typeof(filter)}) = filter(!o.x, obj)


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


end
