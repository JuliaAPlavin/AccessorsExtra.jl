module AccessorsExtra

using Reexport
@reexport using Accessors
using ConstructionBase
using InverseFunctions
using Requires

export ViewLens, Keys, Values, Pairs, @replace


function __init__()
    @require StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a" begin
        using .StructArrays

        Accessors.set(x::StructArray{<:Union{Tuple, NamedTuple}}, ::typeof(StructArrays.components), v) = StructArray(v)
        Accessors.set(x::StructArray{T}, ::typeof(StructArrays.components), v) where {T} = StructArray{T}(v)

        ConstructionBase.setproperties(x::StructArray, patch::NamedTuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))

        Accessors.insert(x::StructArray{<:NamedTuple}, o::Accessors.PropertyLens, v) = insert(x, o ∘ StructArrays.components, v)
        Accessors.delete(x::StructArray{<:NamedTuple}, o::Accessors.PropertyLens) = delete(x, o ∘ StructArrays.components)
    end

    @require SplitApplyCombine = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66" begin
        using .SplitApplyCombine: MappedArray

        # https://github.com/JuliaObjects/Accessors.jl/pull/53
        Base.setindex!(ma::MappedArray, val, ix) = parent(ma)[ix] = set(parent(ma)[ix], ma.f, val)
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
end


# set getfields(): see https://github.com/JuliaObjects/Accessors.jl/pull/57
Accessors.set(obj, o::typeof(getfields), val) = constructorof(typeof(obj))(val...)
Accessors.set(obj, o::Base.Fix2{typeof(getfield)}, val) = @set getfields(obj)[o.x] = val


# ViewLens: adapted from IndexLens
struct ViewLens{I<:Tuple}
    indices::I
end

ViewLens(indices::Integer...) = ViewLens(indices)

Base.@propagate_inbounds function (lens::ViewLens)(obj)
    v = view(obj, lens.indices...)
    ndims(v) == 0 ? v[] : v
end

Base.@propagate_inbounds function Accessors.set(obj, lens::ViewLens, val)
    setindex!(obj, val, lens.indices...)
end


# set axes()
function Accessors.set(obj, ::typeof(axes), v::Tuple)
    res = similar(obj, v)
    @assert size(res) == size(obj)
    copyto!(res, obj)
end

# set vec() using reshape
Accessors.set(x::AbstractArray, ::typeof(vec), v::AbstractVector) = reshape(v, size(x))

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
Accessors.modify(f, obj::Dict, ::Values) = Dict(k => f(v) for (k, v) in pairs(obj))
Accessors.modify(f, obj::Union{AbstractArray, Tuple, NamedTuple}, ::Values) = map(f, obj)

struct Pairs end
Accessors.OpticStyle(::Type{Pairs}) = Accessors.ModifyBased()
Accessors.modify(f, obj::Dict, ::Pairs) = Dict(f(p) for p in pairs(obj))
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


# replace()
_replace(obj, (from, to)::Pair) = insert(delete(obj, from), to, from(obj))
_replace(obj::NamedTuple{NS}, (from, to)::Pair{PropertyLens{A}, PropertyLens{B}}) where {NS, A, B} = NamedTuple{replace(NS, A => B)}(values(obj))

function _replace(obj, optic::ComposedFunction)
    modify(obj, optic.inner) do inner_obj
        _replace(inner_obj, optic.outer)
    end
end

macro replace(ex)
    obj, fromto_optics, inner_optic = if ex.head == :(=)
        @assert length(ex.args) == 2
        to, from = Accessors.parse_obj_optic.(ex.args)
        from_obj, from_optic = from
        to_obj, to_optic = to
        obj = if from_obj == to_obj
            from_obj
        elseif from_obj == esc(:_)
            to_obj
        elseif to_obj == esc(:_)
            from_obj
        else
            throw(ArgumentError("replace requires that the from and to objects are the same; got from = $(from_obj) to = $(to_obj)"))
        end
        obj, :($from_optic => $to_optic), :identity
    else
        obj, optics = Accessors.parse_obj_optics(ex)
        inner_optic = Expr(:call, Accessors.opticcompose, optics[1:end-1]...)
        assignment = optics[end]
        assignment = assignment isa Expr && assignment.head == :escape ? only(assignment.args) : assignment
        @assert assignment.head == :(=) && length(assignment.args) == 2
        to, from = Accessors.parse_obj_optic.(assignment.args)
        from_obj, from_optic = from
        to_obj, to_optic = to
        @assert from_obj == to_obj == esc(:_)
        obj, :($from_optic => $to_optic), inner_optic        
    end
    :($_replace($obj, $fromto_optics ∘ $inner_optic))
end

end
