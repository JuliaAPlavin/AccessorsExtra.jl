module AccessorsExtra

using Reexport
@reexport using Accessors
using ConstructionBase
using Requires

export ViewLens


function __init__()
    @require StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a" begin
        using .StructArrays

        Accessors.set(x::StructArray, ::typeof(StructArrays.components), v) where {T} = StructArray(v)

        # if only Accessors.set is needed, not full setproperties:
        # Accessors.set(x::StructArray, o::Accessors.PropertyLens, v) = set(x, o ∘ StructArrays.components, v)
        ConstructionBase.getproperties(x::StructArray) = StructArrays.components(x)
        ConstructionBase.setproperties(x::StructArray, patch::NamedTuple) = @modify(cs -> setproperties(cs, patch), StructArrays.components(x))

        Accessors.insert(x::StructArray, o::Accessors.PropertyLens, v) = insert(x, o ∘ StructArrays.components, v)
        Accessors.delete(x::StructArray, o::Accessors.PropertyLens) = delete(x, o ∘ StructArrays.components)
    end

    @require SplitApplyCombine = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66" begin
        using .SplitApplyCombine: MappedArray

        # https://github.com/JuliaObjects/Accessors.jl/pull/53
        Base.setindex!(ma::MappedArray, val, ix) = parent(ma)[ix] = set(parent(ma)[ix], ma.f, val)
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

end
