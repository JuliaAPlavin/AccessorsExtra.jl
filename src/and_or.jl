struct ⩓{F,G}
    f::F
    g::G
end
(c::⩓)(x) = c.f(x) && c.g(x)

struct ⩔{F,G}
    f::F
    g::G
end
(c::⩔)(x) = c.f(x) || c.g(x)

Base.:(!)(f::⩓) = ⩔(!f.f, !f.g)
Base.:(!)(f::⩔) = ⩓(!f.f, !f.g)

Base.show(io::IO, f::⩓) = print(io, f.f, " ⩓ ", f.g)
Base.show(io::IO, f::⩔) = print(io, f.f, " ⩔ ", f.g)
