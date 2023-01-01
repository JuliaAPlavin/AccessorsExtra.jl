module AccessorsExtra

using Reexport
@reexport using Accessors
using ConstructionBase
using Requires


function __init__()
    @require StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a" begin
        using .StructArrays

        Accessors.set(x::StructArray, ::typeof(StructArrays.components), v) where {T} = StructArray(v)

        # if only Accessors.set is needed, not full setproperties:
        # Accessors.set(x::StructArray, o::Accessors.PropertyLens, v) = set(x, o ∘ StructArrays.components, v)
        ConstructionBase.getproperties(x::StructArray) = StructArrays.components(x)
        function ConstructionBase.setproperties(x::StructArray, patch::NamedTuple)
            nt = getproperties(x)
            nt_new = merge(nt, patch)
            ConstructionBase.validate_setproperties_result(nt_new, nt, x, patch)
            StructArray(nt_new)
        end

        Accessors.insert(x::StructArray, o::Accessors.PropertyLens, v) = insert(x, o ∘ StructArrays.components, v)
        Accessors.delete(x::StructArray, o::Accessors.PropertyLens) = delete(x, o ∘ StructArrays.components)
    end

    @require SplitApplyCombine = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66" begin
        import .SplitApplyCombine: MappedArray

        # https://github.com/JuliaObjects/Accessors.jl/pull/53
        Base.setindex!(ma::MappedArray, val, ix) = parent(ma)[ix] = set(parent(ma)[ix], ma.f, val)
    end
end

end
