module SciMLExt
using SciMLBase
using AccessorsExtra
using AccessorsExtra: rawfunc, rawdata, rawu, rawbounds, rawcons, rawconsbounds
using AccessorsExtra.DataPipes
using AccessorsExtra.Accessors
using AccessorsExtra.ConstructionBase


ConstructionBase.constructorof(::Type{<:OptimizationFunction{x}}) where {x} = 
    function(args...)
        kwargs = NamedTuple{fieldnames(OptimizationFunction)}(args)
        OptimizationFunction{x}(kwargs.f, kwargs.adtype; @delete(kwargs[(:f, :adtype)])...)
    end

AccessorsExtra.rawfunc(s::OptProblemSpec{<:OptimizationFunction}) = rawfunc(s.func.f, s.x0, s.vars)

struct OptSolution{S<:SciMLBase.OptimizationSolution, O<:OptProblemSpec}
    sol::S
    ops::O
end
Base.propertynames(os::OptSolution) = (propertynames(os.sol)..., :uobj)
Base.getproperty(os::OptSolution, s::Symbol) =
    s == :uobj ? solobj(os.sol, os.ops) :
    s == :sol ? getfield(os, s) :
    s == :ops ? getfield(os, s) :
    getproperty(os.sol, s)
    
SciMLBase.solve(s::OptProblemSpec, args...; kwargs...) =
    OptSolution(solve(OptimizationProblem(s), args...; kwargs...), s)

SciMLBase.OptimizationProblem(s::OptProblemSpec, args...; kwargs...) =
    if isnothing(s.cons)
        OptimizationProblem(rawfunc(s), rawu(s), rawdata(s), args...; rawbounds(s)..., kwargs...)
    else
        OptimizationProblem(OptimizationFunction(rawfunc(s), cons=rawcons(s)), rawu(s), rawdata(s), args...; rawbounds(s)..., rawconsbounds(s)..., kwargs...)
    end

SciMLBase.OptimizationProblem(s::OptProblemSpec{<:OptimizationFunction}, args...; kwargs...) =
    if isnothing(s.cons)
        f = @p s.func |>
            @set(__.f = rawfunc(s))
        OptimizationProblem(f, rawu(s), rawdata(s), args...; rawbounds(s)..., kwargs...)
    else
        f = @p s.func |>
            @set(__.f = rawfunc(s)) |>
            @set __.cons = rawcons(s)
        OptimizationProblem(f, rawu(s), rawdata(s), args...; rawbounds(s)..., rawconsbounds(s)..., kwargs...)
    end

end
