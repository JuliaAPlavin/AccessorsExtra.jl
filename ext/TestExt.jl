module TestExt
using Test
using AccessorsExtra
import AccessorsExtra: test_construct_laws

function test_construct_laws(::Type{T}, pairs...; cmp=(==)) where {T}
    obj = @inferred construct(T, pairs...)
    @assert obj isa T
    for (optic, value) in pairs
        @assert cmp(optic(obj), value)
    end
end

end
