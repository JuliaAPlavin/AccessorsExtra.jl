struct Children end
@inline OpticStyle(::Type{<:Children}) = ModifyBased()
@inline _chooseoptic(obj, c::Children) = _chooseoptic(typeof(obj), c)
@inline _chooseoptic(::Type, ::Children) = Properties()
@inline _chooseoptic(::Type{<:Tuple}, ::Children) = Elements()
@inline _chooseoptic(::Type{<:AbstractArray}, ::Children) = Elements()
@inline _chooseoptic(::Type{<:AbstractDict}, ::Children) = Elements()
@inline getall(obj, c::Children) = getall(obj, _chooseoptic(obj, c))
@inline modify(f, obj, c::Children, objs...) = modify(f, obj, _chooseoptic(obj, c), objs...)
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

# see https://github.com/FluxML/Functors.jl/pull/61 for the approach and its discussion
function modify(f, obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT}
    recurse(o) = _walk_modify(var"#self#", f, o, or)
    _walk_modify(recurse, f, obj, or)
end
_walk_modify(recurse, f, obj, or::RecursiveOfType{Type{OT},Type{RT},ORD}) where {OT,RT,ORD} =
    if obj isa OT
        if ORD === Val{nothing} || !(obj isa RT)
            f(obj)
        elseif ORD === Val{:pre}
            modify(recurse, f(obj), or.optic)
        elseif ORD === Val{:post}
            f(modify(recurse, obj, or.optic))
        else
            error("Unknown order: $ORD")
        end
    elseif obj isa RT
        modify(recurse, obj, or.optic)
    else
        obj
    end

function modify(f, obj, or::RecursiveOfType{Type{OT},Type{RT}}, objb) where {OT,RT}
    recurse(o, b) = _walk_modify(var"#self#", f, o, or, b)
    _walk_modify(recurse, f, obj, or, objb)
end
_walk_modify(recurse, f, obj, or::RecursiveOfType{Type{OT},Type{RT},ORD}, objb) where {OT,RT,ORD} =
    if obj isa OT
        if ORD === Val{nothing} || !(obj isa RT)
            f(obj, objb)
        elseif ORD === Val{:pre}
            modify(recurse, f(obj, objb), or.optic, objb)
        elseif ORD === Val{:post}
            f(modify(recurse, obj, or.optic, objb), objb)
        else
            error("Unknown order: $ORD")
        end
    elseif obj isa RT
        modify(recurse, obj, or.optic, objb)
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


ConcatOptics(obj, or::RecursiveOfType) = ConcatOptics(typeof(obj), or)

ConcatOptics(::Type{T}, or::RecursiveOfType{<:Any,<:Any,Val{nothing}}) where {T} =
    if T <: or.outtypes
        identity
    elseif T <: or.rectypes
        TS = Core.Compiler.return_type(getall, Tuple{T, typeof(or.optic)})
        if _chooseoptic(T, or.optic) === Properties()
            NT = Core.Compiler.return_type(getproperties, Tuple{T})
            opts = map(_propnames(NT), fieldtypes(TS)) do name, ET
                ConcatOptics(ET, or) ∘ᵢ PropertyLens(name)
            end |> Tuple
            concat(opts...)
        elseif _chooseoptic(T, or.optic) === Elements()
            if TS <: Tuple
                opts = map(ntuple(identity, fieldcount(TS)), fieldtypes(TS)) do name, ET
                    ConcatOptics(ET, or) ∘ᵢ IndexLens(name)
                end |> Tuple
                concat(opts...)
            elseif T <: AbstractVector
                ET = eltype(T)
                ConcatOptics(ET, or) ∘ᵢ Elements()
            end
        end
    else
        concat()
    end

∘ᵢ(args...) = ∘(args...)
∘ᵢ(::typeof(identity), args...) = ∘ᵢ(args...)
∘ᵢ(co::ConcatOptics, args...) = concat(map(o -> ∘ᵢ(o, args...), co.optics)...)

_propnames(::Type{T}) where {T<:Tuple} = fieldnames(T)
_propnames(::Type{T}) where {T<:NamedTuple} = fieldnames(T)
