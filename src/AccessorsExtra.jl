module AccessorsExtra

using Reexport
@reexport using Accessors
using DataPipes
using FlexiMaps: filtermap
using ConstructionBase
using ConstructionBaseExtras
using InverseFunctions
using StaticArraysCore: SVector, MVector
using Requires

export
    ViewLens, Keys, Values, Pairs,
    ∗,
    concat, ++,
    @replace,
    assemble, @assemble


include("concatoptic.jl")
include("maybe.jl")
include("regex.jl")
include("replace.jl")
include("assemble.jl")
include("testing.jl")


function __init__()
    @require StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a" begin
        using .StructArrays

        Accessors.set(x::StructArray{<:Union{Tuple, NamedTuple}}, ::typeof(StructArrays.components), v) = StructArray(v)
        Accessors.set(x::StructArray{T}, ::typeof(StructArrays.components), v) where {T} = StructArray{T}(v)

        ConstructionBase.setproperties(x::StructArray, patch::NamedTuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))

        Accessors.insert(x::StructArray{<:NamedTuple}, o::Accessors.PropertyLens, v) = insert(x, o ∘ StructArrays.components, v)
        Accessors.delete(x::StructArray{<:NamedTuple}, o::Accessors.PropertyLens) = delete(x, o ∘ StructArrays.components)
    end

    @require AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5" begin
        using .AxisKeys

        Accessors.set(x::KeyedArray, ::typeof(AxisKeys.axiskeys), v::Tuple) = KeyedArray(AxisKeys.keyless(x), v)
        Accessors.set(x::KeyedArray, ::typeof(AxisKeys.named_axiskeys), v::NamedTuple) = KeyedArray(AxisKeys.keyless_unname(x); v...)
        Accessors.set(x::KeyedArray, ::typeof(AxisKeys.dimnames), v::Tuple{Vararg{Symbol}}) = KeyedArray(AxisKeys.keyless_unname(x); NamedTuple{v}(axiskeys(x))...)

        Accessors.set(x::KeyedArray, f::Base.Fix2{typeof(AxisKeys.axiskeys), Int}, v) = @set axiskeys(x)[f.x] = v
        Accessors.set(x::KeyedArray, f::Base.Fix2{typeof(AxisKeys.axiskeys), Symbol}, v) = @set named_axiskeys(x)[f.x] = v

        ConstructionBase.setproperties(x::KeyedArray, patch::NamedTuple) = @modify(cs -> setproperties(cs, patch), AxisKeys.named_axiskeys(x))

        Accessors.set(x::KeyedArray, ::typeof(AxisKeys.keyless_unname), v::AbstractArray) = KeyedArray(v; named_axiskeys(x)...)
    end

    @require Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f" begin
        using .Distributions

        InverseFunctions.inverse(f::Base.Fix1{typeof(cdf)}) = Base.Fix1(quantile, f.x)
        InverseFunctions.inverse(f::Base.Fix1{typeof(quantile)}) = Base.Fix1(cdf, f.x)
    end

    @require Dictionaries = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4" begin
        using .Dictionaries

        Accessors.modify(f, obj::AbstractDictionary, ::Keys) = constructorof(typeof(obj))(map(f, keys(obj)), values(obj))
        Accessors.modify(f, obj::AbstractDictionary, ::Values) = map(f, obj)
    end

    @require SkyCoords = "fc659fc5-75a3-5475-a2ea-3da92c065361" begin
        using .SkyCoords
        using .SkyCoords: lat, lon

        Accessors.set(x::ICRSCoords, ::typeof(lon), v) = @set x.ra = v
        Accessors.set(x::ICRSCoords, ::typeof(lat), v) = @set x.dec = v
        Accessors.set(x::FK5Coords, ::typeof(lon), v) = @set x.ra = v
        Accessors.set(x::FK5Coords, ::typeof(lat), v) = @set x.dec = v
        Accessors.set(x::GalCoords, ::typeof(lon), v) = @set x.l = v
        Accessors.set(x::GalCoords, ::typeof(lat), v) = @set x.b = v
    end

    @require IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953" begin
        using .IntervalSets

        Accessors.set(x::Interval, ::typeof(endpoints), v::NTuple{2}) = setproperties(x, left=first(v), right=last(v))
        Accessors.set(x::Interval, ::typeof(leftendpoint), v) = @set x.left = v
        Accessors.set(x::Interval, ::typeof(rightendpoint), v) = @set x.right = v
        Accessors.set(x::Interval, ::typeof(closedendpoints), v::NTuple{2, Bool}) = Interval{v[1] ? :closed : :open, v[2] ? :closed : :open}(endpoints(x)...)

        Accessors.set(x, f::Base.Fix2{typeof(mod), <:Interval}, v) = @set x |> mod(_, width(f.x)) = v - leftendpoint(f.x)
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


# set getfields(): see https://github.com/JuliaObjects/Accessors.jl/pull/57
Accessors.set(obj, o::typeof(getfields), val) = constructorof(typeof(obj))(val...)
Accessors.set(obj, o::Base.Fix2{typeof(getfield)}, val) = @set getfields(obj)[o.x] = val


# ViewLens: adapted from IndexLens
struct ViewLens{I<:Tuple}
    indices::I
end

ViewLens(indices::Integer...) = ViewLens(indices)

Base.@propagate_inbounds (lens::ViewLens{<:Tuple{Vararg{Integer}}})(obj) = obj[lens.indices...]
Base.@propagate_inbounds (lens::ViewLens)(obj) = view(obj, lens.indices...)

Base.@propagate_inbounds Accessors.set(obj, lens::ViewLens, val) = setindex!(obj, val, lens.indices...)
Base.@propagate_inbounds Accessors.set(obj, lens::Base.Fix2{typeof(view)}, val) = setindex!(obj, val, lens.x)


# set axes()
function Accessors.set(obj, ::typeof(axes), v::Tuple)
    res = similar(obj, v)
    @assert length(res) == length(obj)
    copyto!(res, obj)
end

# set on ranges
Accessors.set(r::AbstractRange, ::typeof(step), s) = range(first(r), last(r), step=s)
Accessors.set(r::AbstractRange, ::typeof(length), l) = range(first(r), last(r), length=l)
Accessors.set(r::AbstractRange, ::typeof(first), x) = range(x,  last(r), step=step(r))
Accessors.set(r::AbstractRange, ::typeof(last),  x) = range(first(r), x, step=step(r))
Accessors.set(r::AbstractUnitRange, ::typeof(first), x) = range(x,  last(r))
Accessors.set(r::AbstractUnitRange, ::typeof(last),  x) = range(first(r), x)
Accessors.set(r::Base.OneTo, ::typeof(last),  x) = Base.OneTo(x)

# inverse getindex
InverseFunctions.inverse(f::Base.Fix1{typeof(getindex)}) = Base.Fix2(findfirst, f.x) ∘ isequal
InverseFunctions.inverse(f::ComposedFunction{<:Base.Fix2{typeof(findfirst)}, typeof(isequal)}) = Base.Fix1(getindex, f.outer.x)

# optics inspired by https://juliaobjects.github.io/Accessors.jl/stable/examples/custom_optics/
struct Keys end
Accessors.OpticStyle(::Type{Keys}) = Accessors.ModifyBased()
Accessors.modify(f, obj::Dict, ::Keys) = Dict(f(k) => v for (k, v) in pairs(obj))
Accessors.modify(f, obj::NamedTuple{NS}, ::Keys) where {NS} = NamedTuple{map(f, NS)}(values(obj))

struct Values end
Accessors.OpticStyle(::Type{Values}) = Accessors.ModifyBased()
Accessors.modify(f, obj::Union{AbstractArray, Tuple, NamedTuple}, ::Values) = map(f, obj)
function Accessors.modify(f, dict::Dict, ::Values)
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
Accessors.OpticStyle(::Type{Pairs}) = Accessors.ModifyBased()
Accessors.modify(f, obj::AbstractArray, ::Pairs) = map(eachindex(obj), obj) do i, x
    p = f(i => x)
    @assert first(p) == i
    last(p)
end
Accessors.modify(f, obj::Tuple, ::Pairs) = ntuple(length(obj)) do i
    p = f(i => obj[i])
    @assert first(p) == i
    last(p)
end
Accessors.modify(f, obj::NamedTuple, ::Pairs) = map(keys(obj), values(obj)) do k, v
    p = f(k => v)
    @assert first(p) == k
    last(p)
end |> NamedTuple{keys(obj)}
Accessors.modify(f, obj::Dict, ::Pairs) = Dict(f(p) for p in pairs(obj))


function ConstructionBase.setproperties(d::Dict, patch::NamedTuple{(:vals,)})
    K = keytype(d)
    V = eltype(patch.vals)
    @assert length(d.keys) == length(patch.vals)
    Dict{K,V}(copy(d.slots), copy(d.keys), patch.vals, d.ndel, d.count, d.age, d.idxfloor, d.maxprobe)
end


const ∗ = Val(:∗)

Accessors.IndexLens(::Tuple{typeof(∗)}) = Elements()
Accessors._shortstring(prev, o::Elements) = "$prev[∗]"

@generated Accessors.PropertyLens{P}() where {P} = P == :∗ ? Properties() : Expr(:new, PropertyLens{P})
Accessors._shortstring(prev, o::Properties) = "$prev.:∗"


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
function Accessors.set(obj, lens::FuncValLens, val)
    func(args...; kwargs...) = if args == lens.args && values(kwargs) == lens.kwargs
        val
    else
        obj(args...; kwargs...)
    end
end

end
