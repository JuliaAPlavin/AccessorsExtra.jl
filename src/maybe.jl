
struct MaybeOptic{O,D}
    o::O
    default::D
end

export maybe
maybe(o; default=nothing) = MaybeOptic(o, default)

# Accessors.OpticStyle(::Type{<:MaybeOptic}) = Accessors.ModifyBased()

(o::MaybeOptic{<:IndexLens})(obj::AbstractArray) =
    checkbounds(Bool, obj, o.o.indices...) ? o.o(obj) : o.default

Accessors.set(obj::AbstractArray, o::MaybeOptic{<:IndexLens}, val) =
    checkbounds(Bool, obj, o.o.indices...) ? set(obj, o.o, val) : insert(obj, o.o, val)

Accessors.modify(f, obj::AbstractArray, o::MaybeOptic{<:IndexLens}) =
    checkbounds(Bool, obj, o.o.indices...) ? modify(f, obj, o.o) : obj
