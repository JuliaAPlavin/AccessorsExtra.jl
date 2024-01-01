module AccessorsExtra

using Reexport
@reexport using Accessors
using Accessors: compose, opcompose, decompose, deopcompose
import Accessors: set, modify, getall, setall, OpticStyle, SetBased, ModifyBased
using DataPipes
using ConstructionBase
using InverseFunctions
using Requires
using Accessors: MacroTools

export
    ∗, ∗ₚ, All,
    concat, ++, @optics, @optic₊,
    @replace,
    assemble, @assemble,
    unrecurcize, RecursiveOfType,
    keyed, enumerated, selfcontext,
    maybe, hasoptic,
    get_steps, logged


include("keyvalues.jl")
include("flexix.jl")
include("concatoptic.jl")
include("alongside.jl")
include("recursive.jl")
include("context.jl")
include("maybe.jl")
include("regex.jl")
include("replace.jl")
include("assemble.jl")
include("bystep.jl")
include("testing.jl")


function __init__()
    @require SkyCoords = "fc659fc5-75a3-5475-a2ea-3da92c065361" begin
        using .SkyCoords
        using .SkyCoords: lat, lon

        set(x::ICRSCoords, ::typeof(lon), v) = @set x.ra = v
        set(x::ICRSCoords, ::typeof(lat), v) = @set x.dec = v
        set(x::FK5Coords, ::typeof(lon), v) = @set x.ra = v
        set(x::FK5Coords, ::typeof(lat), v) = @set x.dec = v
        set(x::GalCoords, ::typeof(lon), v) = @set x.l = v
        set(x::GalCoords, ::typeof(lat), v) = @set x.b = v
    end

    @require Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d" begin
        using .Unitful

        InverseFunctions.inverse(f::Base.Fix1{typeof(ustrip)}) = Base.Fix1(*, true*f.x)
    end
end


InverseFunctions.inverse(::typeof(deopcompose)) = Base.splat(opcompose)
InverseFunctions.inverse(::typeof(Base.splat(opcompose))) = deopcompose
InverseFunctions.inverse(::typeof(decompose)) = Base.splat(compose)
InverseFunctions.inverse(::typeof(Base.splat(compose))) = decompose


set(obj, o::Base.Fix1{typeof(map)}, val) = map((ob, v) -> set(ob, o.x, v), obj, val)
set(obj, o::Base.Fix1{typeof(filter)}, val) = @set obj[findall(o.x, obj)] = val
modify(f, obj, o::Base.Fix1{typeof(filter)}) = @modify(f, obj[findall(o.x, obj)])

Base.@propagate_inbounds set(obj, lens::Base.Fix2{typeof(view)}, val) = setindex!(obj, val, lens.x)
Base.@propagate_inbounds set(obj, lens::Base.Fix2{typeof(view), <:Integer}, val::AbstractArray{<:Any, 0}) = setindex!(obj, only(val), lens.x)


# set getfields(): see https://github.com/JuliaObjects/Accessors.jl/pull/57
set(obj, o::typeof(getfields), val) = constructorof(typeof(obj))(val...)
set(obj, o::Base.Fix2{typeof(getfield)}, val) = @set getfields(obj)[o.x] = val

# inverse getindex
InverseFunctions.inverse(f::Base.Fix1{typeof(getindex)}) = Base.Fix2(findfirst, f.x) ∘ isequal
InverseFunctions.inverse(f::ComposedFunction{<:Base.Fix2{typeof(findfirst)}, typeof(isequal)}) = Base.Fix1(getindex, f.outer.x)


const ∗ = Elements()
const ∗ₚ = Properties()

Accessors.IndexLens(::Tuple{typeof(∗)}) = Elements()
Accessors._shortstring(prev, o::Elements) = "$prev[∗]"

Accessors.IndexLens(::Tuple{typeof(∗ₚ)}) = Properties()
Accessors._shortstring(prev, o::Properties) = "$prev[∗ₚ]"


struct FuncValLens{A <: Tuple, KA <: NamedTuple}
    args::A
    kwargs::KA
end

function funcvallens(args...; kwargs...)
    @assert args == args
    @assert values(kwargs) == values(kwargs)
    FuncValLens(args, values(kwargs))
end

(lens::FuncValLens)(obj) = obj(lens.args...; lens.kwargs...)
function set(obj, lens::FuncValLens, val)
    func(args...; kwargs...) = if args == lens.args && values(kwargs) == lens.kwargs
        val
    else
        obj(args...; kwargs...)
    end
end


struct FuncResult end
OpticStyle(::Type{FuncResult}) = ModifyBased()
modify(f, obj, ::FuncResult) = f ∘ obj

struct FuncArgument end
OpticStyle(::Type{FuncArgument}) = ModifyBased()
modify(f, obj, ::FuncArgument) = obj ∘ f


set(obj, ::typeof(sort), val) = @set obj[sortperm(obj)] = val



struct All end
struct _AllOptic{O}
    o::O
end
OpticStyle(::Type{_AllOptic}) = ModifyBased()
(o::_AllOptic)(obj) = getall(obj, o.o)
set(obj, o::_AllOptic, val) = setall(obj, o.o, val)

Base.:∘(i::All, o) = _AllOptic(o)
Base.:∘(i::_AllOptic, o) = _AllOptic(i.o ∘ o)
Base.:∘(c::ComposedFunction{<:Any, <:All}, o) = c.outer ∘ _AllOptic(o)
Base.:∘(c::ComposedFunction{<:Any, <:_AllOptic}, o) = c.outer ∘ _AllOptic(c.inner.o ∘ o)

end
