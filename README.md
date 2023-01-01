# AccessorsExtra.jl

`AccessorsExtra` provides Accessors.jl integrations with lots of third-party packages, and implements additional optics.

The [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl) package defines a unified interface to modify immutable data structures. See its docs for details and background.

`AccessorsExtra.jl` defines more optics, focusing on those that operate on types defined in other packages. It also implements several more general optics, not tied to particular types. They are somewhat too opinionated to be included into a package as foundational as `Accessors` itself.

Integrations with more -- reasonably common -- packages are also in scope for `AccessorsExtra.jl`.

See the [Pluto notebook](https://aplavin.github.io/AccessorsExtra.jl/test/notebook.html) for more details and usage examples.
