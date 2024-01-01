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




struct LoggedOptic{O}
    o::O
    depth::Int
end
Broadcast.broadcastable(o::LoggedOptic) = Ref(o)
OpticStyle(::Type{LoggedOptic{O}}) where {O} = OpticStyle(O)

logged(o::ComposedFunction; depth=0) = @modify(deopcompose(o)) do ops
    map(enumerate(ops)) do (i, op)
        logged(op, depth=depth + i - 1)
    end
end
logged(o::Union{ConcatOptics,AlongsideOptic}; depth=0) =
    LoggedOptic(@modify(f -> logged(f; depth=depth+1), o.optics[∗]), depth)
logged(o; depth=0) = LoggedOptic(o, depth)

function (o::LoggedOptic)(obj)
    @info _indent(o.depth) * "┌ get $(repr(obj)) |> $(repr(o.o))"
    res = o.o(obj)
    @info _indent(o.depth) * "└ $(repr(res))"
    res
end

function set(obj, o::LoggedOptic, value)
    prev_str = OpticStyle(o) isa SetBased ?
        repr(o.o(obj)) : "<…>"
    @info _indent(o.depth) * "┌ set $(repr(obj)) |> $(repr(o.o)): $prev_str => $(repr(value))"
    res = set(obj, o.o, value)
    @info _indent(o.depth) * "└ $(repr(res))"
    res
end

function modify(f, obj, o::LoggedOptic)
    prev_str = OpticStyle(o) isa SetBased ?
        "; prev = $(repr(o.o(obj)))" : ""
    @info(_indent(o.depth) * "┌ modify $(repr(obj)) |> $(repr(o.o)) with $f $prev_str")
    res = modify(f, obj, o.o)
    @info _indent(o.depth) * "└ $(repr(res))"
    res
end

function getall(obj, o::LoggedOptic)
    @info _indent(o.depth) * "┌ getall $(repr(obj)) |> $(repr(o.o))"
    res = getall(obj, o.o)
    @info _indent(o.depth) * "└ $(repr(res))"
    res
end

function setall(obj, o::LoggedOptic, values)
    @info _indent(o.depth) * "┌ setall $(repr(obj)) |> $(repr(o.o)): $(repr(getall(obj, o.o))) => $(repr(values))"
    res = setall(obj, o.o, values)
    @info _indent(o.depth) * "└ $(repr(res))"
    res
end

_indent(depth) = "┆ "^depth


# Base.show(io::IO, co::LoggedOptic) = print(io, "logged(", co.o, "; depth=", co.depth, ")")
Base.show(io::IO, co::LoggedOptic) = print(io, co.o)
Base.show(io::IO, ::MIME"text/plain", optic::LoggedOptic) = show(io, optic)
