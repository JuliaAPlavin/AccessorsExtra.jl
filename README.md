# AccessorsExtra.jl

Advanced optics/lenses and relevant tools, based on the `Accessors.jl` framework.

The [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl) package defines a unified interface to modify immutable data structures --- so-called optics or lenses. See its docs for details and background.
`AccessorsExtra.jl` defines more optics and relevant tools that are too experimental or opinionated to be included into a package as foundational as `Accessors` itself.

This notebook showcases the more stable and widely applicable pieces of functionality defined in `AccessorsExtra`. See the source code and tests for more.

As far as possible, `AccessorsExtra` operations attempt to have as little overhead as possible, with tests checking this. Not all operations are possible to make zero-cost given the current Julia compiler state, though.

See the Pluto notebooks for more details:
- [Common usage examples](https://aplavin.github.io/AccessorsExtra.jl/examples/notebook.html)
- [Optimization integration](https://aplavin.github.io/AccessorsExtra.jl/examples/optimization.html)
