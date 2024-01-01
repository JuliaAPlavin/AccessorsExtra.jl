# AccessorsExtra.jl

Advanced optics/lenses and relevant tools, based on the `Accessors.jl` framework.

The [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl) package defines a unified interface to modify immutable data structures --- so-called optics or lenses. See its docs for details and background. \
`AccessorsExtra.jl` defines more optics and relevant tools that are too involved/opinionated/experimental to be included into a package as foundational as `Accessors` itself.

Following `Accessors` itself, optics and operations in `AccessorsExtra` aim to have as little overhead as possible, often zero, with tests checking this.

Some featured examples:
```julia
julia> obj = (a=1, b=(2, 3, "4"))

# multi-valued optics
julia> o = @optic₊ (_.a, _.b[2])
julia> o(obj)
(1, 3)
julia> @set o(obj) = (:x, :y)
(a = :x, b = (2, :y, "4"))

# recursive optics
julia> o = RecursiveOfType(Number)
julia> getall(obj, o)
(1, 2, 3)
julia> modify(x -> x+1, obj, o)
(a = 2, b = (3, 4, "4"))

# optional optics
julia> o = maybe(@optic _.b[2])
julia> o(obj)
3
julia> o((a=1, c=3))
nothing
```

See the Pluto notebooks for more details:
- [Usage examples](https://aplavin.github.io/AccessorsExtra.jl/examples/notebook.html) notebook showcases widely applicable optics defined in `AccessorsExtra`
- [`Optimization.jl` integration](https://aplavin.github.io/AccessorsExtra.jl/examples/optimization.html) demonstrates using optics together with `Optimization.jl` to optimize functions with respect to arbitrary struct parameters
