module RotationsExt

using Rotations: Rotation
using AccessorsExtra: Properties
import AccessorsExtra: Children, _chooseoptic_bytype

# rotations are AbstractArrays, but their parts are the parameters (angles, quaternion, matrix):
# rebuilding a rotation from modified matrix elements would turn it into a plain matrix
_chooseoptic_bytype(::Type{<:Rotation}, ::Children) = Properties()

end
