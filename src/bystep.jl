struct Thrown
    e
end
Base.show(io::IO, t::Thrown) = print(io, "Thrown(", t.e, ")")
Base.show(io::IO, ::MIME"text/plain", t::Thrown) = show(io, t)


get_steps(obj, o) = last(_get_steps(obj, o))

function _get_steps(obj, o)
    g = try
        o(obj)
    catch e
        Thrown(e)
    end
    g, [(;o, g)]
end
_get_steps(obj::Thrown, o) = obj, [(;o, g=nothing)]

function _get_steps(obj, o::ComposedFunction)
    iobj, isteps = _get_steps(obj, o.inner)
    oobj, osteps = _get_steps(iobj, o.outer)
    oobj, vcat(isteps, osteps)
end
_get_steps(obj::Thrown, o::ComposedFunction) = Base.@invoke _get_steps(obj::Any, o::ComposedFunction)
