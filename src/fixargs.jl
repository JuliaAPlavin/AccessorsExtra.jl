struct Placeholder end

struct FixArgs{F, T<:Tuple, NT<:NamedTuple}
    f::F
    args::T
    kwargs::NT
end

function fixargs(f, args...; kwargs...)
    @assert Placeholder() ∈ args
    @assert Placeholder() ∉ values(kwargs)
    FixArgs(f, args, values(kwargs))
end

@inline function (fa::FixArgs)(arg)
    args = map(x -> x isa Placeholder ? arg : x, fa.args)
    fa.f(args...; fa.kwargs...)
end

function Base.show(io::IO, fa::FixArgs)
    print(io, "(@optic ")
    print(io, fa.f, "(")
    for (i, arg) in enumerate(fa.args)
        i > 1 && print(io, ", ")
        print(io, arg isa Placeholder ? "_" : arg)
    end
    print(io, "; ", fa.kwargs)
    print(io, "))")
end
Base.show(io::IO, ::MIME"text/plain", fa::FixArgs) = show(io, fa)
