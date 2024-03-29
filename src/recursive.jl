struct Children end
@inline OpticStyle(::Type{<:Children}) = ModifyBased()
@inline _chooseoptic_byval(obj, c::Children) = _chooseoptic_bytype(typeof(obj), c)
@inline _chooseoptic_bytype(::Type, ::Children) = Properties()
@inline _chooseoptic_bytype(::Type{<:Type}, ::Children) = ConcatOptics(())
@inline _chooseoptic_bytype(::Type{<:Tuple}, ::Children) = Elements()
@inline _chooseoptic_bytype(::Type{<:AbstractArray}, ::Children) = Elements()
@inline _chooseoptic_bytype(::Type{<:AbstractDict}, ::Children) = Elements()
@inline getall(obj, c::Children) = getall(obj, _chooseoptic_byval(obj, c))
@inline modify(f, obj, c::Children, objs...) = modify(f, obj, _chooseoptic_byval(obj, c), objs...)
@inline setall(obj, c::Children, vals) = setall(obj, _chooseoptic_byval(obj, c), vals)


"""    RecursiveOfType(out::Type, [optic=Children()]; [recurse::Type=Any])

Optic that references all values of type `out` located arbitrarily deep.

Recurses into values of type `recurse` (`Any` by default) using the specified inner `optic`.
The default of `Children()` descends into all properties of objects, or into all elements of a collection.

___Note:___ typically, when changing the `optic` parameter, the `recurse` type should be narrowed as well.

## Examples

```julia
julia> obj = ([1,2,3], (a=[4,5], b=[6], c=([7], [8,9])));

# extract all numbers from the object:
julia> getall(obj, RecursiveOfType(Number))
9-element Vector{Int64}:
 1
 2
 3
 4
 5
 6
 7
 8
 9

# extract the first element of each vector:
julia> getall(obj, @o _ |> RecursiveOfType(Vector) |> first)
(1, 4, 6, 7, 8)

# negate the first element of each vector:
julia> modify(x -> -x, obj, @o _ |> RecursiveOfType(Vector) |> first)
([-1, 2, 3], (a = [-4, 5], b = [-6], c = ([-7], [-8, 9])))
```
"""
struct RecursiveOfType{OT,RT,ORD,O}
    outtypes::OT
    rectypes::RT
    order::ORD
    optic::O
end
Broadcast.broadcastable(o::RecursiveOfType) = Ref(o)
function RecursiveOfType(out::Type{TO}, optic=Children(); recurse::Type{TR}=Any, order=nothing) where {TO,TR}
    _check_order(order)
    RecursiveOfType{Type{TO},Type{TR},Val{order},typeof(optic)}(out, recurse, Val(order), optic)
end
_check_order(order) = order ∈ (nothing, :pre, :post) || error("Unknown recursive order: $order. Must be `nothing`, `:pre`, or `:post`.")

OpticStyle(::Type{<:RecursiveOfType}) = ModifyBased()

# straightforward implementation, but suffers from recursion inference limits:
# function modify(f, obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT}
#     if obj isa OT && obj isa RT
#         f(modify(obj, or.optic) do part
#             modify(f, part, or)
#         end)
#     elseif obj isa RT
#         modify(obj, or.optic) do part
#             modify(f, part, or)
#         end
#     elseif obj isa OT
#         f(obj)
#     else
#         obj
#     end
# end

# see https://github.com/FluxML/Functors.jl/pull/61 for the var"#self#" approach and its discussion
function modify(f, obj, or::RecursiveOfType{Type{OT},Type{RT}}, objs...) where {OT,RT}
    recurse(o, bs...) = _walk_modify(var"#self#", f, o, or, bs...)
    _walk_modify(recurse, f, obj, or, objs...)
end
_walk_modify(recurse, f, obj, or::RecursiveOfType{Type{OT},Type{RT},ORD}, objs...) where {OT,RT,ORD} =
    if obj isa OT
        if ORD === Val{nothing} || !(obj isa RT)
            f(obj, objs...)
        elseif ORD === Val{:pre}
            modify(recurse, f(obj, objs...), or.optic, objs...)
        elseif ORD === Val{:post}
            f(modify(recurse, obj, or.optic, objs...), objs...)
        else
            error("Unknown order: $ORD")
        end
    elseif obj isa RT
        modify(recurse, obj, or.optic, objs...)
    else
        obj
    end

function getall(obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT}
    recurse(o) = _walk_getall(var"#self#", o, or)
    _walk_getall(recurse, obj, or)
end
_walk_getall(recurse, obj, or::RecursiveOfType{Type{OT},Type{RT},ORD}) where {OT,RT,ORD} =
    if obj isa OT
        if ORD === Val{nothing} || !(obj isa RT)
            return (obj,)
        elseif ORD === Val{:pre}
            return (obj, _getall(recurse, obj, or.optic)...)
        elseif ORD === Val{:post}
            return (_getall(recurse, obj, or.optic)..., obj)
        else
            error("Unknown order: $ORD")
        end
    elseif obj isa RT
        _getall(recurse, obj, or.optic)
    else
        ()
    end
_getall(recurse, obj, optic) = @p getall(obj, optic) |> map(recurse) |> _reduce_concat

_setall_T(obj, or::Type{<:RecursiveOfType{<:Any,<:Any,Val{ORD},<:Any}}, istart) where {ORD} = error("Recursive setall not supported with order = $ORD")
function _setall_T(obj::Type{T}, or::Type{RecursiveOfType{Type{OT},Type{RT},Val{nothing},O}}, istart::Val{I}) where {T,OT,RT,O,I}
    curcnt = 0
    full_expr = if T <: OT
        curcnt += 1
        :(vals[$(I + curcnt - 1)])
    elseif T <: RT
        TS = Core.Compiler.return_type(getall, Tuple{T, O})
        if TS == Union{} || !isconcretetype(TS)
            error("Cannot recurse on $T |> $(O): got $TS")
        end

        exprs = map(enumerate(_eltypes(TS))) do (ifield, ET)
            expr, cnt = _setall_T(ET, or, Val(I + curcnt))
            curcnt += cnt
            return :(let obj = oldvs[$(ifield)];
                $expr
            end)
        end
        :(let oldvs = getall(obj, or.optic)
            newvs = ($(exprs...),)
            setall(obj, or.optic, newvs)
        end)
    else
        :obj
    end
    return full_expr, curcnt
end

_eltypes(::Type{T}) where {T<:Tuple} = fieldtypes(T)
_eltypes(::Type{T}) where {T<:AbstractVector} = ntuple(Returns(eltype(T)), _typelength(T))  # only for StaticArrays

_typelength(::Type{T}) where {T<:Tuple} = fieldcount(T)
# only for StaticArrays:
_typelength(::Type{T}) where {T<:AbstractVector} = fieldcount(only(fieldtypes(T))) # this hack because length(T) doesn't work due to worldage

@generated function setall(obj::T, or::ORT, vals::VT) where {T,ORT<:RecursiveOfType,VT}
    expr, cnt = _setall_T(T, ORT, Val(1))
    return quote
        length(vals) == $cnt || throw(DimensionMismatch("tried to assign $(length(vals)) elements to $($cnt) destinations"))
        $expr
    end
end

tree_concatoptic(::Type{T}, o::Children) where {T} = tree_concatoptic(T, _chooseoptic_bytype(T, o))
tree_concatoptic(::Type{T}, or::RecursiveOfType{<:Any,<:Any,Val{nothing}}) where {T} = 
    if T <: or.outtypes
        identity
    elseif T <: or.rectypes
        tree_concatoptic(T, or ∘ or.optic)
    else
        concat()
    end
