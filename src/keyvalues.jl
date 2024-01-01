# trivial setters
set(obj::AbstractArray, ::typeof(values), vals::AbstractArray) = (@assert axes(obj) == axes(vals); vals)
# XXX: setall should be improved in Accessors, see OffsetArrays tests
# set(obj::AbstractArray, ::typeof(values), vals) = setall(obj, Elements(), vals)
set(obj::Tuple, ::typeof(values), vals) = Tuple(vals)
set(obj::Pair, ::typeof(values), vals) = Pair(vals...)
set(obj::NamedTuple{KS}, ::typeof(values), vals) where {KS} = NamedTuple{KS}(Tuple(vals))
set(obj::NamedTuple{KS}, ::typeof(keys), vals::NTuple{<:Any,Symbol}) where {KS} = NamedTuple{vals}(values(obj))

# inspired by https://juliaobjects.github.io/Accessors.jl/stable/examples/custom_optics/ but cleaner? :)

# special wrapper type, can only be modify'ed with Elements()
struct KVPWrapper{TO,T}
    o::TO
    obj::T
end

modify(f, obj::AbstractDict, o::Union{typeof(keys),typeof(values)}) = f(KVPWrapper(o, obj))
modify(f, obj, o::typeof(pairs)) = f(KVPWrapper(o, obj))
modify(f, obj::AbstractDict, o::typeof(pairs)) = f(obj)
modify(f, obj::KVPWrapper, ::Elements) = error("modify(f, ::$(typeof(obj.obj)), $(obj.o ⨟ Elements())) not supported")

### keys
modify(f, obj::KVPWrapper{typeof(keys), <:Dict}, ::Elements) = Dict(f(k) => v for (k, v) in pairs(obj.obj))
modify(f, obj::KVPWrapper{typeof(keys), <:NamedTuple{NS}}, ::Elements) where {NS} = NamedTuple{map(f, NS)}(values(obj.obj))

### values - just map by default
modify(f, obj::KVPWrapper{typeof(values)}, ::Elements) = map(f, obj.obj)

modify(f, obj::KVPWrapper{typeof(values), <:Pair}, ::Elements) = modify(f, obj.obj, Properties())

function modify(f, obj::KVPWrapper{typeof(values), <:Dict}, ::Elements)
    dict = obj.obj
    @modify(dict.vals) do vals
        V = Core.Compiler.return_type(f, Tuple{eltype(vals)})
        newvals = similar(vals, V)
        @inbounds for i in dict.idxfloor:lastindex(vals)
            if Base.isslotfilled(dict, i)
                newvals[i] = f(vals[i])
            end
        end
        return newvals
    end
end

### pairs
modify(f, obj::KVPWrapper{typeof(pairs), <:AbstractArray}, ::Elements) =
    map(eachindex(obj.obj), obj.obj) do i, x
        p = f(i => x)
        @assert first(p) == i
        last(p)
    end
modify(f, obj::KVPWrapper{typeof(pairs), <:Tuple}, ::Elements) =
    ntuple(length(obj.obj)) do i
        p = f(i => obj.obj[i])
        @assert first(p) == i
        last(p)
    end
modify(f, obj::KVPWrapper{typeof(pairs), <:NamedTuple{NS}}, ::Elements) where {NS} =
    map(NS, values(obj.obj)) do k, v
        p = f(k => v)
        @assert first(p) == k
        last(p)
    end |> NamedTuple{NS}


# see https://github.com/JuliaObjects/ConstructionBase.jl/pull/47
function ConstructionBase.setproperties(d::Dict, patch::NamedTuple{(:vals,)})
    K = keytype(d)
    V = eltype(patch.vals)
    @assert length(d.keys) == length(patch.vals)
    Dict{K,V}(copy(d.slots), copy(d.keys), patch.vals, d.ndel, d.count, d.age, d.idxfloor, d.maxprobe)
end
