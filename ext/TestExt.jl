module TestExt
using Test
using AccessorsExtra
import AccessorsExtra: test_construct_laws

function test_construct_laws(::Type{T}, pairs...; cmp=(==), type=T, inferred=true) where {T}
    obj = if inferred
        @inferred construct(T, pairs...)
    else
        construct(T, pairs...)
    end
    @assert obj isa type
    for (optic, value) in pairs
        @assert cmp(optic(obj), value)
    end
end

end
