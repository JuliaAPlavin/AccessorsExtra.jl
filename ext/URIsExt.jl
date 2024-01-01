module URIsExt

using URIs
import AccessorsExtra.ConstructionBase: getproperties, setproperties, check_patch_properties_exist, constructorof

# XXX: piracy, should upstream
setproperties(obj::URI, patch::NamedTuple) = @invoke setproperties(obj::Any, merge((uri="",), patch))

end
