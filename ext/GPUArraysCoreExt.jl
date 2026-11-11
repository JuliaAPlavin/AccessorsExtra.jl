module GPUArraysCoreExt

using GPUArraysCore: AbstractGPUArray
using AccessorsExtra
import AccessorsExtra: Children, _chooseoptic_bytype

# GPU arrays are leaves: their elements cannot be traversed from the host
_chooseoptic_bytype(::Type{<:AbstractGPUArray}, ::Children) = concat()

end
