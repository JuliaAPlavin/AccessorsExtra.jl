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

Base.:(==)(a::FuncValLens, b::FuncValLens) = a.args == b.args && a.kwargs == b.kwargs


struct FuncResult end
OpticStyle(::Type{FuncResult}) = ModifyBased()
modify(f, obj, ::FuncResult) = f ∘ obj

struct FuncArgument end
OpticStyle(::Type{FuncArgument}) = ModifyBased()
modify(f, obj, ::FuncArgument) = obj ∘ f
