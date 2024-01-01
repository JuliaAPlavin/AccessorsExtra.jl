module URIsExt

using URIs
import AccessorsExtra.ConstructionBase: getproperties, setproperties, check_patch_properties_exist, constructorof

# XXX: piracy, should upstream
function setproperties(obj::URI, patch::NamedTuple)
    nt = getproperties(obj)
    nt_new = merge(nt, (uri="",), patch)
    check_patch_properties_exist(nt_new, nt, obj, patch)
    args = Tuple(nt_new) # old julia inference prefers if we wrap in Tuple
    constructorof(typeof(obj))(args...)
end

end
