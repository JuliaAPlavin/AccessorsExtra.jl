module AccessorsExtra

using Reexport
@reexport using Accessors
using Accessors: compose, opcompose, decompose, deopcompose
import Accessors: set, modify, getall, setall, OpticStyle, SetBased, ModifyBased
using DataPipes
using FlexiMaps: filtermap
using ConstructionBase
using ConstructionBaseExtras
using InverseFunctions
using StaticArraysCore: SVector, MVector
using Requires

export
    ViewLens,
    ∗, ∗ₚ, All,
    concat, ++, @optics, @optic₊,
    @replace,
    assemble, @assemble,
    unrecurcize, RecursiveOfType,
    keyed, enumerated, selfindexed,
    maybe, hasoptic,
    get_steps, logged


include("flexix.jl")
include("concatoptic.jl")
include("alongside.jl")
include("recursive.jl")
include("indexed.jl")
include("maybe.jl")
include("regex.jl")
include("replace.jl")
include("assemble.jl")
include("bystep.jl")
include("testing.jl")


function __init__()
    @require StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a" begin
        using .StructArrays

        set(x::StructArray{<:Union{Tuple, NamedTuple}}, ::typeof(StructArrays.components), v) = StructArray(v)
        set(x::StructArray{T}, ::typeof(StructArrays.components), v) where {T} = StructArray{T}(v)

        ConstructionBase.setproperties(x::StructArray, patch::NamedTuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))

        Accessors.insert(x::StructArray{<:NamedTuple}, o::Accessors.PropertyLens, v) = insert(x, o ∘ StructArrays.components, v)
        Accessors.delete(x::StructArray{<:NamedTuple}, o::Accessors.PropertyLens) = delete(x, o ∘ StructArrays.components)
    end

    @require AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5" begin
        using .AxisKeys

        set(x::KeyedArray, ::typeof(AxisKeys.axiskeys), v::Tuple) = KeyedArray(AxisKeys.keyless(x), v)
        set(x::KeyedArray, ::typeof(AxisKeys.named_axiskeys), v::NamedTuple) = KeyedArray(AxisKeys.keyless_unname(x); v...)
        set(x::KeyedArray, ::typeof(AxisKeys.dimnames), v::Tuple{Vararg{Symbol}}) = KeyedArray(AxisKeys.keyless_unname(x); NamedTuple{v}(axiskeys(x))...)

        set(x::KeyedArray, f::Base.Fix2{typeof(AxisKeys.axiskeys), Int}, v) = @set axiskeys(x)[f.x] = v
        set(x::KeyedArray, f::Base.Fix2{typeof(AxisKeys.axiskeys), Symbol}, v) = @set named_axiskeys(x)[f.x] = v

        ConstructionBase.setproperties(x::KeyedArray, patch::NamedTuple) = @modify(cs -> setproperties(cs, patch), AxisKeys.named_axiskeys(x))

        set(x::KeyedArray, ::typeof(AxisKeys.keyless_unname), v::AbstractArray) = KeyedArray(v; named_axiskeys(x)...)
    end

    @require Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f" begin
        using .Distributions

        InverseFunctions.inverse(f::Base.Fix1{typeof(cdf)}) = Base.Fix1(quantile, f.x)
        InverseFunctions.inverse(f::Base.Fix1{typeof(quantile)}) = Base.Fix1(cdf, f.x)
    end

    @require Dictionaries = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4" begin
        using .Dictionaries

        modify(f, obj::AbstractDictionary, ::Keys) = constructorof(typeof(obj))(map(f, keys(obj)), values(obj))
        modify(f, obj::AbstractDictionary, ::Values) = map(f, obj)
    end

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

    @require IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953" begin
        using .IntervalSets

        set(x::Interval, ::typeof(endpoints), v::NTuple{2}) = setproperties(x, left=first(v), right=last(v))
        set(x::Interval, ::typeof(leftendpoint), v) = @set x.left = v
        set(x::Interval, ::typeof(rightendpoint), v) = @set x.right = v
        set(x::Interval, ::typeof(closedendpoints), v::NTuple{2, Bool}) = Interval{v[1] ? :closed : :open, v[2] ? :closed : :open}(endpoints(x)...)

        set(x, f::Base.Fix2{typeof(mod), <:Interval}, v) = @set x |> mod(_, width(f.x)) = v - leftendpoint(f.x)
    end

    @require Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d" begin
        using .Unitful

        InverseFunctions.inverse(f::Base.Fix1{typeof(ustrip)}) = Base.Fix1(*, 1*f.x)
    end
end


@generated function ConstructionBase.setproperties(obj::Union{SVector{N}, MVector{N}}, patch::NamedTuple{KS}) where {N, KS}
    if KS == (:data,)
        :( constructorof(typeof(obj))(only(patch)) )
    else
        propnames = (:x, :y, :z, :w)[1:N]
        KS ⊆ propnames || error("type $obj does not have properties $KS")
        field_exprs = map(enumerate(propnames)) do (i, p)
            from = p ∈ KS ? :patch : :obj
            :( $from.$p )
        end
        :( constructorof(typeof(obj))($(field_exprs...)) )
    end
end


InverseFunctions.inverse(::typeof(deopcompose)) = Base.splat(opcompose)
InverseFunctions.inverse(::typeof(Base.splat(opcompose))) = deopcompose
InverseFunctions.inverse(::typeof(decompose)) = Base.splat(compose)
InverseFunctions.inverse(::typeof(Base.splat(compose))) = decompose


Accessors.constructorof(::Type{<:Expr}) = (head, args) -> Expr(head, args...)


# set getfields(): see https://github.com/JuliaObjects/Accessors.jl/pull/57
set(obj, o::typeof(getfields), val) = constructorof(typeof(obj))(val...)
set(obj, o::Base.Fix2{typeof(getfield)}, val) = @set getfields(obj)[o.x] = val


# ViewLens: adapted from IndexLens
struct ViewLens{I<:Tuple}
    indices::I
end

ViewLens(indices::Integer...) = ViewLens(indices)

Base.@propagate_inbounds (lens::ViewLens{<:Tuple{Vararg{Integer}}})(obj) = obj[lens.indices...]
Base.@propagate_inbounds (lens::ViewLens)(obj) = view(obj, lens.indices...)

Base.@propagate_inbounds set(obj, lens::ViewLens, val) = setindex!(obj, val, lens.indices...)
Base.@propagate_inbounds set(obj, lens::Base.Fix2{typeof(view)}, val) = setindex!(obj, val, lens.x)

# inverse getindex
InverseFunctions.inverse(f::Base.Fix1{typeof(getindex)}) = Base.Fix2(findfirst, f.x) ∘ isequal
InverseFunctions.inverse(f::ComposedFunction{<:Base.Fix2{typeof(findfirst)}, typeof(isequal)}) = Base.Fix1(getindex, f.outer.x)


# optics inspired by https://juliaobjects.github.io/Accessors.jl/stable/examples/custom_optics/
struct Keys end
OpticStyle(::Type{Keys}) = ModifyBased()
modify(f, obj::Dict, ::Keys) = Dict(f(k) => v for (k, v) in pairs(obj))
modify(f, obj::NamedTuple{NS}, ::Keys) where {NS} = NamedTuple{map(f, NS)}(values(obj))

struct Values end
OpticStyle(::Type{Values}) = ModifyBased()
modify(f, obj::Union{AbstractArray, Tuple, NamedTuple}, ::Values) = map(f, obj)
function modify(f, dict::Dict, ::Values)
    V = Core.Compiler.return_type(f, Tuple{valtype(dict)})
    vals = dict.vals
    newvals = similar(vals, V)
    @inbounds for i in dict.idxfloor:lastindex(vals)
        if Base.isslotfilled(dict, i)
            newvals[i] = f(vals[i])
        end
    end
    setproperties(dict, vals=newvals)
end

struct Pairs end
OpticStyle(::Type{Pairs}) = ModifyBased()
modify(f, obj::AbstractArray, ::Pairs) = map(eachindex(obj), obj) do i, x
    p = f(i => x)
    @assert first(p) == i
    last(p)
end
modify(f, obj::Tuple, ::Pairs) = ntuple(length(obj)) do i
    p = f(i => obj[i])
    @assert first(p) == i
    last(p)
end
modify(f, obj::NamedTuple, ::Pairs) = map(keys(obj), values(obj)) do k, v
    p = f(k => v)
    @assert first(p) == k
    last(p)
end |> NamedTuple{keys(obj)}
modify(f, obj::Dict, ::Pairs) = Dict(f(p) for p in pairs(obj))


for (f, o) in [
    (values, Values),
    (keys, Keys),
    (pairs, Pairs),
]
    @eval Base.:∘(i::Elements, o::typeof($f)) = $o()
    @eval Base.:∘(c::ComposedFunction{<:Any, <:Elements}, o::typeof($f)) = c.outer ∘ $o()
end


function ConstructionBase.setproperties(d::Dict, patch::NamedTuple{(:vals,)})
    K = keytype(d)
    V = eltype(patch.vals)
    @assert length(d.keys) == length(patch.vals)
    Dict{K,V}(copy(d.slots), copy(d.keys), patch.vals, d.ndel, d.count, d.age, d.idxfloor, d.maxprobe)
end


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

end
