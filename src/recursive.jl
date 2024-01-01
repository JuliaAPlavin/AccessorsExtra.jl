struct Children end
@inline OpticStyle(::Type{<:Children}) = ModifyBased()
@inline _chooseoptic(obj, ::Children) = Properties()
@inline _chooseoptic(obj::AbstractArray, ::Children) = Elements()
@inline _chooseoptic(obj::AbstractDict, ::Children) = Elements()
@inline getall(obj, c::Children) = getall(obj, _chooseoptic(obj, c))
@inline modify(f, obj, c::Children) = modify(f, obj, _chooseoptic(obj, c))
@inline setall(obj, c::Children, vals) = setall(obj, _chooseoptic(obj, c), vals)


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
struct RecursiveOfType{OT,RT,O}
    outtypes::OT
    rectypes::RT
    optic::O
end
Broadcast.broadcastable(o::RecursiveOfType) = Ref(o)
RecursiveOfType(out::Type{TO}, optic=Children(); recurse::Type{TR}=Any) where {TO,TR} =
    RecursiveOfType{Type{TO},Type{TR},typeof(optic)}(out, recurse, optic)


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

# see https://github.com/FluxML/Functors.jl/pull/61 for the approach and its discussion
function modify(f, obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT}
    recurse(o) = _walk_modify(var"#self#", f, o, or)
    _walk_modify(recurse, f, obj, or)
end
_walk_modify(recurse, f, obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT} =
    if obj isa OT && obj isa RT
        f(modify(recurse, obj, or.optic))
    elseif obj isa RT
        modify(recurse, obj, or.optic)
    elseif obj isa OT
        f(obj)
    else
        obj
    end


function getall(obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT}
    recurse(o) = _walk_getall(var"#self#", o, or)
    _walk_getall(recurse, obj, or)
end
_walk_getall(recurse, obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT} =
    if obj isa OT && obj isa RT
        (_getall(recurse, obj, or.optic)..., obj)
    elseif obj isa RT
        _getall(recurse, obj, or.optic)
    elseif obj isa OT
        (obj,)
    else
        ()
    end
_getall(recurse, obj, optic) = @p getall(obj, optic) |> map(recurse) |> _reduce_concat

function _setall_T(obj::Type{T}, or::Type{RecursiveOfType{Type{OT},Type{RT},O}}, istart::Val{I}) where {T,OT,RT,O,I}
    curcnt = 0
    rec_expr = if T <: RT
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
    full_expr = if T <: OT
        curcnt += 1
        :(vals[$(I + curcnt - 1)])
    else
        rec_expr
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
