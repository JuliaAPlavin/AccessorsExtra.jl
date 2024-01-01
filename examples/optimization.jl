### A Pluto.jl notebook ###
# v0.19.24

using Markdown
using InteractiveUtils

# ╔═╡ 3fa1d138-6e8e-4e8b-bfac-71536628eeb8
using IntervalSets

# ╔═╡ c5915064-60e6-4180-a4e9-8e8a4e91b020
using StructArrays

# ╔═╡ 4bdd0dcd-ca89-4102-bfa9-926683fee155
using DataPipes

# ╔═╡ f03679e5-5d9e-41e5-bff2-c02822181d01
using FlexiMaps

# ╔═╡ 22433e08-4ab4-4a23-b079-5b73b9ae6128
using DataManipulation: uniqueonly

# ╔═╡ 6115a5f1-6d34-4c10-985d-6abe36275978
using PyPlotUtils; pyplot_style!()

# ╔═╡ 6d0e158d-ba36-4100-86bf-44b878b30356
using Optimization

# ╔═╡ 58165c5e-b292-4b54-90a2-24b911095af7
using OptimizationOptimJL

# ╔═╡ 27ebaf90-bdc4-408b-9b7a-c951d3a64c8c
using Metaheuristics; using OptimizationMetaheuristics: ECA

# ╔═╡ c7d1204a-8edf-4f36-b9f9-dc6e08477a0b
using AccessorsExtra

# ╔═╡ a5db525e-1ee9-4451-a933-c3041166e38a
using StaticArrays: SVector, MVector

# ╔═╡ 719aafc6-9a82-4b22-ae96-0ba843327c0a
using BenchmarkTools

# ╔═╡ 1d5d7187-fbac-4d4f-8a02-31f6251fcd72
using ProfileCanvas

# ╔═╡ 31766e3e-1d86-4d2a-8330-9838283d2f90
using StaticNumbers: static

# ╔═╡ acb4555e-969b-4ee7-a4af-7341a9eb5388
md"""
Imprort required packages:
"""

# ╔═╡ e0ea9f28-bafc-4566-9b22-d00a2253d9e9
md"""
Define a struct representing the model, along with a way to evaluate it.

This is standard Julia code, nothing specific to optimization or `Accessors`.
"""

# ╔═╡ 3f22a7ae-bd49-478c-8f74-391bb6cf11cc
begin
	struct ExpModel{A,B}
		scale::A
		shift::B
	end
	
	struct SumModel{T <: Tuple}
		comps::T
	end
	
	(m::ExpModel)(x) = m.scale * exp(-(x - m.shift)^2)
	(m::SumModel)(x) = sum(c -> c(x), m.comps)
end

# ╔═╡ 3d0d0368-031d-4a04-b66c-2dc5e8be00a0
md"""
Generate or load an dataset, and define the loss function.

Again, this is plain Julia code. Here, we create the dataset from our model (`truemod`) with some noise.
"""

# ╔═╡ ea815f0c-8e7e-4b9d-a765-34baf0242140
truemod = SumModel((
	ExpModel(2, 5),
	ExpModel(0.5, 2),
	ExpModel(0.5, 8),
))

# ╔═╡ 9257a65d-7dd1-41c3-8071-19ecf9115797
data = @p 0:0.2:10 |> StructArray(x=__, y=truemod.(__) .+ 0.03 .* randn.())

# ╔═╡ 8412b028-a559-4566-bd51-c4650a8edf73
loss(m, data) = sum(r -> abs2(r.y - m(r.x)), data)

# ╔═╡ 63d598fa-02a6-4d36-94f4-43831a5de8d1
let
	plt.figure()
	plt.plot(data.x, data.y, ".-")
	plt.gcf()
end

# ╔═╡ 25355d27-0766-468d-9c7c-edf0ee743711
md"Create an instance of the model struct. Some or all parameters would be optimized afterwards."

# ╔═╡ ff8ded6f-6f7d-41ac-93a0-11ff1f6f2a40
mod0 = SumModel((
	ExpModel(1, 1),
	ExpModel(1, 2),
	ExpModel(1, 3),
))

# ╔═╡ 29faf78f-a44f-48cc-9e07-80cc70f6764c
md"""
It's only at this point where we encounter code specific to parameter optimization.

Let's define the parameters to be optimized. They are represented as `Accessors` optics and possible value bounds:
"""

# ╔═╡ 79ede060-9bf1-4a71-a92b-493b9d4fce8e
vars = OptArgs(
	@optic(_.comps[∗].shift) => 0..10.,
	@optic(_.comps[∗].scale) => 0.3..10.,
)

# ╔═╡ a53461db-00d3-48da-9a03-116311c10b5a
md"Optionally, define a set of constrains: each is a function of the model, and the interval of bounds."

# ╔═╡ 4a97d36d-81f6-447f-ba26-6f0ebb93217c
cons = OptCons(
	((x, _) -> mean(c -> c.shift, x.comps)) => 0.5..4,
)

# ╔═╡ ae16f334-e583-4fac-8c34-c5b4e60f248f
md"""
Create an optimization problem definition.

This step is equivalent to `OptimizationProblem(loss, ops, data)` in `Optimization.jl` itself, but here we can work with arbitrary structs and parameter definitions instead of vectors.
"""

# ╔═╡ 0340001b-8282-4fb7-94a1-cfec5c2ecfb6
# supported variants:
# ops = OptProblemSpec(MVector{<:Any, Float64}, mod0, vars)
# ops = OptProblemSpec(Tuple, mod0, vars)
# ops = OptProblemSpec(Vector{Float64}, mod0, vars)
# ops = OptProblemSpec(mod0, vars)
# ops = OptProblemSpec(Base.Fix2(loss, data), Vector, mod0, vars)
ops = OptProblemSpec(Base.Fix2(loss, data), SVector, mod0, vars)
# ops = OptProblemSpec(Base.Fix2(OptimizationFunction(loss, Optimization.AutoForwardDiff()), data), Vector{Float64}, mod0, vars, cons)

# equivalents in Optimization.jl itself:
# prob = OptimizationProblem(loss, ops, data)
# prob = OptimizationProblem(OptimizationFunction(loss, Optimization.AutoForwardDiff()), ops, data)

# ╔═╡ b923b0fd-f373-48b0-8689-0bdef2780c54
md"Finally, run `solve` on the problem. Same interface as in `Optimization` itself:"

# ╔═╡ 0e679fb7-1baf-4545-aef5-eb564e41db54
sol = solve(ops, ECA(), maxiters=300)
# sol = solve(prob, Optim.GradientDescent(), maxiters=300)
# sol = solve(ops, Optim.IPNewton(), maxiters=300)

# ╔═╡ eab52f13-6ff0-4fbc-80c9-782ef03b6e7a
md"""
`sol.u` is the resulting vector of parameters, directly provided by `Optimization`. All other solution properties are available as well.
"""

# ╔═╡ c4d2d970-c468-4d18-852f-846cb81a2d7a
sol.u

# ╔═╡ 17e4ff5b-ddd6-404f-a092-4c7c9b18cfed
md"While `sol.uobj` is the model object with its parameters optimized. This is provided by `AccessorsExtra`:"

# ╔═╡ 337a4039-2349-454e-b6dc-6a8d584b58a9
sol.uobj

# ╔═╡ 6c8f8970-4ff3-4b7a-b537-970cd6055e59
md"""
Further, we'll demonstrate fitting the same model, but with different parameters fixed/optimized.

Let's define convenience functions to fit and plot the results:
"""

# ╔═╡ b51f9964-1e19-4078-a2c6-6109e935a000
function solmod_from_vars(vars)
	prob = OptProblemSpec(Base.Fix2(loss, data), mod0, vars)
	sol = solve(prob, ECA(), maxiters=300)
	return sol.uobj
end

# ╔═╡ 66acd240-f950-4c2a-bc06-1ac2c5929544
function plot_datamod(data, mod)
	plt.figure()
	plt.plot(data.x, data.y, ".-")
	datamod = @set data.y = mod.(data.x)
	plt.plot(datamod.x, datamod.y, ".-")
	plt.gcf()
end

# ╔═╡ fd5c3705-a79e-4898-a94c-6ceb966a1334
md"Only optimize the first component shift, leaving everything else constant:"

# ╔═╡ bd06ef56-c099-4631-b895-0fa68da0f8ff
let
	vars = OptArgs(
		@optic(_.comps[1].shift) => 0..10.,
	)
	mod = solmod_from_vars(vars)
	plot_datamod(data, mod), mod
end

# ╔═╡ 04c2526e-b991-43f0-aea3-ff816a2bc9de
md"Optimize scales and shifts of all components - specify them manually:"

# ╔═╡ 90757798-7aa5-46e8-8c7b-d7c66b47b865
let
	vars = OptArgs(
		@optic(_.comps[∗].scale) => 0..10.,
		@optic(_.comps[∗].shift) => 0..10.,
	)
	mod = solmod_from_vars(vars)
	plot_datamod(data, mod), mod
end

# ╔═╡ 2c648777-a967-4129-8640-504fd523852f
md"""
Optimize scales and shifts of all components - specified via a recursive optic:
"""

# ╔═╡ 52baa97e-dcd4-4ba7-8492-6f1179522562
let
	vars = OptArgs(
		RecursiveOfType(Number) => 0..10.,
	)
	mod = solmod_from_vars(vars)
	plot_datamod(data, mod), mod
end

# ╔═╡ 4fe4e530-813d-4f8f-8a74-de08de26c3aa
md"Optimize scales and shifts of all components, while two scales (#2 and #3) are kept exactly the same:"

# ╔═╡ d741b31f-e947-4650-bcba-9d9b8f842726
let
	vars = OptArgs(
		@optic(_.comps[1].scale) => 0..10.,
		@optic(_.comps[2:3][∗].scale |> PartsOf() |> uniqueonly) => 0..1.,
		@optic(_.comps[∗].shift) => 0..10.,
	)
	mod = solmod_from_vars(vars)
	plot_datamod(data, mod), mod
end

# ╔═╡ dc57e188-20f6-4c7e-bef0-955547f2482f


# ╔═╡ 52735849-5810-46d6-bfa6-7fc67ba8c1c3
md"Some bechmarks to demonstrate little or no overhead:"

# ╔═╡ cdba5bb2-d52b-41d6-85ff-4011fc570a11
x0 = SumModel((
	ExpModel(2, 0),
	ExpModel(0, 0),
	ExpModel(0, 0),
))

# ╔═╡ 7cafbcf6-57d4-4f07-87e7-74504e98d4f3
bvars = OptArgs(
	@optic(first(_.comps).shift) => 0..10.,
	@optic(_.comps[static(1:2)][∗].shift) => 0..10.,
	@optic(_.comps[static(2:3)][∗].scale |> PartsOf() |> uniqueonly) => 0..10.,
)

# ╔═╡ 67fc7546-e287-4001-a0cd-d5f74a94f3bc
bops = OptProblemSpec(Base.Fix2(loss, data), Vector, x0, bvars)
# bops = OptProblemSpec(Base.Fix2(loss, data), SVector, x0, bvars)

# ╔═╡ 30b8cec9-3c00-49ea-bf9f-76fe26fe5a87
u = @btime AccessorsExtra.rawu($bops)

# ╔═╡ 15ca9bd4-8ced-462b-b34f-b781a041c1f1
@btime AccessorsExtra.fromrawu($u, $bops)

# ╔═╡ f0ede4eb-1811-48e7-9a2b-49e7f67ae7a8
func = AccessorsExtra.rawfunc(bops)

# ╔═╡ 708951df-5d62-4e06-9493-9886f95e426d
@btime loss($x0, $data)

# ╔═╡ 6e6eac98-7825-467a-bd59-ee33ec66c321
@btime func($u, $data)

# ╔═╡ 88801de8-abd8-4306-8504-04edbf2ee518
@btime AccessorsExtra.rawbounds($bops)

# ╔═╡ 53f5d11d-7f29-48ad-a9be-d6ab67b763f0


# ╔═╡ b0ff9d1d-82fd-4d85-a976-2182c7ce0833

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AccessorsExtra = "33016aad-b69d-45be-9359-82a41f556fd4"
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
DataManipulation = "38052440-ad76-4236-8414-61389b2c5143"
DataPipes = "02685ad9-2d12-40c3-9f73-c6aeda6a7ff5"
FlexiMaps = "6394faf6-06db-4fa8-b750-35ccc60383f7"
IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
Metaheuristics = "bcdb8e00-2c21-11e9-3065-2b553b22f898"
Optimization = "7f7a1694-90dd-40f0-9382-eb1efda571ba"
OptimizationMetaheuristics = "3aafef2f-86ae-4776-b337-85a36adf0b55"
OptimizationOptimJL = "36348300-93cb-4f02-beb5-3c3902f8871e"
ProfileCanvas = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
PyPlotUtils = "5384e752-6c47-47b3-86ac-9d091b110b31"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
StaticNumbers = "c5e4b96a-f99f-5557-8ed2-dc63ef9b5131"
StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"

[compat]
AccessorsExtra = "~0.1.36"
BenchmarkTools = "~1.3.2"
DataManipulation = "~0.1.10"
DataPipes = "~0.3.8"
FlexiMaps = "~0.1.14"
IntervalSets = "~0.7.4"
Metaheuristics = "~3.2.16"
Optimization = "~3.13.1"
OptimizationMetaheuristics = "~0.1.2"
OptimizationOptimJL = "~0.1.7"
ProfileCanvas = "~0.1.6"
PyPlotUtils = "~0.1.27"
StaticArrays = "~1.5.21"
StaticNumbers = "~0.4.0"
StructArrays = "~0.6.15"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0-rc2"
manifest_format = "2.0"
project_hash = "b02e6415d08b56b4717b768076b78c43f3e6145c"

[[deps.AbstractTrees]]
git-tree-sha1 = "faa260e4cb5aba097a73fab382dd4b5819d8ec8c"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.4"

[[deps.Accessors]]
deps = ["Compat", "CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "LinearAlgebra", "MacroTools", "Requires", "Test"]
git-tree-sha1 = "beabc31fa319f9de4d16372bff31b4801e43d32c"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.28"

    [deps.Accessors.extensions]
    AxisKeysExt = "AxisKeys"
    IntervalSetsExt = "IntervalSets"
    StaticArraysExt = "StaticArrays"
    StructArraysExt = "StructArrays"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"

[[deps.AccessorsExtra]]
deps = ["Accessors", "ConstructionBase", "DataPipes", "InverseFunctions", "Reexport", "Requires"]
git-tree-sha1 = "0c7a6e03137ad3f5f9220c850879177b4eff726e"
uuid = "33016aad-b69d-45be-9359-82a41f556fd4"
version = "0.1.36"
weakdeps = ["Dictionaries", "SciMLBase", "StructArrays"]

    [deps.AccessorsExtra.extensions]
    DictionariesExt = "Dictionaries"
    SciMLExt = "SciMLBase"
    StructArraysExt = "StructArrays"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "cc37d689f599e8df4f464b2fa3870ff7db7492ef"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.6.1"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra", "Requires", "SnoopPrecompile", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "38911c7737e123b28182d89027f4216cfc8a9da7"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.4.3"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "d9a9701b899b30332bbcb3e1679c41cce81fb0e8"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.2"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "fc08e5930ee9a4e03f84bfb5211cb54e7769758a"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.10"

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[deps.CommonSolve]]
git-tree-sha1 = "9441451ee712d1aec22edad62db1a9af3dc8d852"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.3"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "7a60c856b9fa189eb34f5f8a6f6b5529b7942957"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.6.1"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.CompositeTypes]]
git-tree-sha1 = "02d2316b7ffceff992f3096ae48c7829a8aa0638"
uuid = "b152e2b5-7a66-4b01-a709-34e65c35f657"
version = "0.1.3"

[[deps.CompositionsBase]]
git-tree-sha1 = "455419f7e328a1a2493cabc6428d79e951349769"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.1"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "e32a90da027ca45d84678b826fffd3110bb3fc90"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.8.0"

[[deps.ConsoleProgressMonitor]]
deps = ["Logging", "ProgressMeter"]
git-tree-sha1 = "3ab7b2136722890b9af903859afcf457fa3059e8"
uuid = "88cd18e8-d9cc-4ea6-8889-5259c0d15c8b"
version = "0.1.2"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "89a9db8d28102b094992472d333674bd1a83ce2a"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.1"
weakdeps = ["IntervalSets", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    IntervalSetsExt = "IntervalSets"
    StaticArraysExt = "StaticArrays"

[[deps.DataAPI]]
git-tree-sha1 = "e8119c1a33d267e16108be441a287a6981ba1630"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.14.0"

[[deps.DataManipulation]]
deps = ["Accessors", "DataPipes", "FlexiGroups", "FlexiMaps", "InverseFunctions", "Reexport", "Skipper"]
git-tree-sha1 = "d8ee99ca6d5d1572e19bb5c83525a85fd03c34b8"
uuid = "38052440-ad76-4236-8414-61389b2c5143"
version = "0.1.10"
weakdeps = ["Dictionaries", "IntervalSets", "StructArrays"]

    [deps.DataManipulation.extensions]
    DictionariesExt = "Dictionaries"
    IntervalSetsExt = "IntervalSets"
    StructArraysExt = "StructArrays"

[[deps.DataPipes]]
git-tree-sha1 = "3b4bc031d472fbcee3335ceadd85b399dfdd8006"
uuid = "02685ad9-2d12-40c3-9f73-c6aeda6a7ff5"
version = "0.3.8"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Dictionaries]]
deps = ["Indexing", "Random", "Serialization"]
git-tree-sha1 = "e82c3c97b5b4ec111f3c1b55228cebc7510525a2"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.3.25"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "a4ad7ef19d2cdc2eff57abbbe68032b1cd0bd8f8"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.13.0"

[[deps.DirectionalStatistics]]
deps = ["Accessors", "IntervalSets", "InverseFunctions", "LinearAlgebra", "Statistics", "StatsBase"]
git-tree-sha1 = "68542d40cdd14dac113199f5bcdd0b06922476cc"
uuid = "e814f24e-44b0-11e9-2fd5-aba2b6113d95"
version = "0.1.23"

[[deps.Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "49eba9ad9f7ead780bfb7ee319f962c811c6d3b2"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.8"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.DomainSets]]
deps = ["CompositeTypes", "IntervalSets", "LinearAlgebra", "Random", "StaticArrays", "Statistics"]
git-tree-sha1 = "698124109da77b6914f64edd696be8dccf90229e"
uuid = "5b8099bc-c8ec-5219-889f-1d9e522a28bf"
version = "0.6.6"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[deps.ExprTools]]
git-tree-sha1 = "c1d06d129da9f55715c6c212866f5b1bddc5fa00"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.9"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "fc86b4fd3eff76c3ce4f5e96e2fdfa6282722885"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.0.0"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "Setfield", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "03fcb1c42ec905d15b305359603888ec3e65f886"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.19.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.FlexiGroups]]
deps = ["AccessorsExtra", "Combinatorics", "DataPipes", "Dictionaries", "FlexiMaps"]
git-tree-sha1 = "998cd0985e2cca6b10cd62daf0c4b8388224a765"
uuid = "1e56b746-2900-429a-8028-5ec1f00612ec"
version = "0.1.15"

    [deps.FlexiGroups.extensions]
    AxisKeysExt = "AxisKeys"
    CategoricalArraysExt = "CategoricalArrays"

    [deps.FlexiGroups.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    CategoricalArrays = "324d7699-5711-5eae-9e2f-1d82baa6b597"

[[deps.FlexiMaps]]
deps = ["Accessors", "InverseFunctions"]
git-tree-sha1 = "e5a6fa9d8ee0dae4edc8c07212262b810e2aa570"
uuid = "6394faf6-06db-4fa8-b750-35ccc60383f7"
version = "0.1.14"
weakdeps = ["Dictionaries", "StructArrays"]

    [deps.FlexiMaps.extensions]
    DictionariesExt = "Dictionaries"
    StructArraysExt = "StructArrays"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "00e252f4d706b3d55a8863432e742bf5717b498d"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.35"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FunctionWrappers]]
git-tree-sha1 = "d62485945ce5ae9c0c48f124a84998d755bae00e"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.3"

[[deps.FunctionWrappersWrappers]]
deps = ["FunctionWrappers"]
git-tree-sha1 = "b104d487b34566608f8b4e1c39fb0b10aa279ff8"
uuid = "77dc65aa-8811-40c2-897b-53d922fa7daf"
version = "0.1.3"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "1cd7f0af1aa58abc02ea1d872953a97359cb87fa"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.4"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IntervalSets]]
deps = ["Dates", "Random", "Statistics"]
git-tree-sha1 = "16c0cc91853084cb5f58a78bd209513900206ce6"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.4"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "49510dfcb407e572524ba94aeae2fced1f3feb0f"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.8"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JMcDM]]
deps = ["Requires"]
git-tree-sha1 = "2a74366a90bc8c9f9f2f8009a97718dff7882693"
uuid = "358108f5-d052-4d0a-8344-d5384e00c0e5"
version = "0.7.3"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.Lazy]]
deps = ["MacroTools"]
git-tree-sha1 = "1370f8202dac30758f3c345f9909b97f53d87d3f"
uuid = "50d2b5c4-7a5e-59d5-8109-a42b560f39c0"
version = "0.15.1"

[[deps.LeftChildRightSiblingTrees]]
deps = ["AbstractTrees"]
git-tree-sha1 = "fb6803dafae4a5d62ea5cab204b1e657d9737e7f"
uuid = "1d6d02ad-be62-4b6b-8a6d-2f90e265016e"
version = "0.2.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "7bbea35cec17305fc70a0e5b4641477dc0789d9d"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.2.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "0a1b7c2863e44523180fdb3146534e265a91870b"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.23"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "cedb76b37bc5a6c702ade66be44f831fa23c681e"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Metaheuristics]]
deps = ["Distances", "JMcDM", "LinearAlgebra", "Pkg", "Printf", "Random", "Requires", "SnoopPrecompile", "Statistics"]
git-tree-sha1 = "b04a029b36629e59b27790f0993a57d2075942c7"
uuid = "bcdb8e00-2c21-11e9-3065-2b553b22f898"
version = "3.2.16"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.NonNegLeastSquares]]
deps = ["Distributed", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "1271344271ffae97e2855b0287356e6ea5c221cc"
uuid = "b7351bd1-99d9-5c5d-8786-f205a815c4d7"
version = "0.4.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "a89b11f0f354f06099e4001c151dffad7ebab015"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.7.5"

[[deps.Optimization]]
deps = ["ArrayInterface", "ConsoleProgressMonitor", "DocStringExtensions", "Logging", "LoggingExtras", "Pkg", "Printf", "ProgressLogging", "Reexport", "Requires", "SciMLBase", "SparseArrays", "TerminalLoggers"]
git-tree-sha1 = "012e44804e52b157e3180b52c504636b52af5ea4"
uuid = "7f7a1694-90dd-40f0-9382-eb1efda571ba"
version = "3.13.1"

[[deps.OptimizationMetaheuristics]]
deps = ["Metaheuristics", "Optimization", "Reexport"]
git-tree-sha1 = "cfebe60075b98b53aa1b61e79650335c79531ade"
uuid = "3aafef2f-86ae-4776-b337-85a36adf0b55"
version = "0.1.2"

[[deps.OptimizationOptimJL]]
deps = ["Optim", "Optimization", "Reexport", "SparseArrays"]
git-tree-sha1 = "d654b063a6c63e107d0a44a6a79430e2d0ab30d2"
uuid = "36348300-93cb-4f02-beb5-3c3902f8871e"
version = "0.1.7"

[[deps.OrderedCollections]]
git-tree-sha1 = "d321bf2de576bf25ec4d3e4360faca399afca282"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "478ac6c952fddd4399e71d4779797c538d0ff2bf"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.8"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

[[deps.PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.ProfileCanvas]]
deps = ["Base64", "JSON", "Pkg", "Profile", "REPL"]
git-tree-sha1 = "e42571ce9a614c2fbebcaa8aab23bbf8865c624e"
uuid = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
version = "0.1.6"

[[deps.ProgressLogging]]
deps = ["Logging", "SHA", "UUIDs"]
git-tree-sha1 = "80d919dee55b9c50e8d9e2da5eeafff3fe58b539"
uuid = "33c8b6b6-d38a-422a-b730-caa89a2f386c"
version = "0.1.4"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "d7a7aef8f8f2d537104f170139553b14dfe39fe9"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.2"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "62f417f6ad727987c755549e9cd88c46578da562"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.95.1"

[[deps.PyPlot]]
deps = ["Colors", "LaTeXStrings", "PyCall", "Sockets", "Test", "VersionParsing"]
git-tree-sha1 = "92e7ca803b579b8b817f004e74b205a706d9a974"
uuid = "d330b81b-6aea-500a-939a-2ce795aea3ee"
version = "2.11.1"

[[deps.PyPlotUtils]]
deps = ["Accessors", "ColorTypes", "DataPipes", "DirectionalStatistics", "DomainSets", "FlexiMaps", "IntervalSets", "LinearAlgebra", "NonNegLeastSquares", "PyCall", "PyPlot", "Statistics", "StatsBase"]
git-tree-sha1 = "a14a65db8b0a6866292e0ba422ecc752c1c1530c"
uuid = "5384e752-6c47-47b3-86ac-9d091b110b31"
version = "0.1.27"

    [deps.PyPlotUtils.extensions]
    AxisKeysExt = "AxisKeys"
    AxisKeysUnitfulExt = ["AxisKeys", "Unitful"]
    UnitfulExt = "Unitful"

    [deps.PyPlotUtils.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
deps = ["SnoopPrecompile"]
git-tree-sha1 = "261dddd3b862bd2c940cf6ca4d1c8fe593e457c8"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.3"

[[deps.RecursiveArrayTools]]
deps = ["Adapt", "ArrayInterface", "DocStringExtensions", "GPUArraysCore", "IteratorInterfaceExtensions", "LinearAlgebra", "RecipesBase", "Requires", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "140cddd2c457e4ebb0cdc7c2fd14a7fbfbdf206e"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "2.38.3"

    [deps.RecursiveArrayTools.extensions]
    RecursiveArrayToolsMeasurementsExt = "Measurements"
    RecursiveArrayToolsTrackerExt = "Tracker"
    RecursiveArrayToolsZygoteExt = "Zygote"

    [deps.RecursiveArrayTools.weakdeps]
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.RuntimeGeneratedFunctions]]
deps = ["ExprTools", "SHA", "Serialization"]
git-tree-sha1 = "f139e81a81e6c29c40f1971c9e5309b09c03f2c3"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.6"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SciMLBase]]
deps = ["ArrayInterface", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "EnumX", "FunctionWrappersWrappers", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "Markdown", "Preferences", "RecipesBase", "RecursiveArrayTools", "Reexport", "RuntimeGeneratedFunctions", "SciMLOperators", "SnoopPrecompile", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables", "TruncatedStacktraces"]
git-tree-sha1 = "392d3e28b05984496af37100ded94dc46fa6c8de"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "1.91.7"

[[deps.SciMLOperators]]
deps = ["ArrayInterface", "DocStringExtensions", "Lazy", "LinearAlgebra", "Setfield", "SparseArrays", "StaticArraysCore", "Tricks"]
git-tree-sha1 = "e61e48ef909375203092a6e83508c8416df55a83"
uuid = "c0aeaf25-5076-4817-a8d5-81caf7dfa961"
version = "0.2.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.Skipper]]
git-tree-sha1 = "778668a7dcb7eba533cd00c501b69435df3ace13"
uuid = "fc65d762-6112-4b1c-b428-ad0792653d81"
version = "0.1.7"
weakdeps = ["Accessors", "Dictionaries"]

    [deps.Skipper.extensions]
    AccessorsExt = "Accessors"
    DictionariesExt = "Dictionaries"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "a4ada03f999bd01b3a25dcaa30b2d929fe537e00"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "ef28127915f4229c971eb43f3fc075dd3fe91880"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.2.0"

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

    [deps.SpecialFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "63e84b7fdf5021026d0f17f76af7c57772313d99"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.21"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.StaticNumbers]]
git-tree-sha1 = "b54bf9e3b0914394584270460284692720071d64"
uuid = "c5e4b96a-f99f-5557-8ed2-dc63ef9b5131"
version = "0.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "45a7769a04a3cf80da1c1c7c60caf932e6f4c9f7"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.6.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "GPUArraysCore", "StaticArraysCore", "Tables"]
git-tree-sha1 = "521a0e828e98bb69042fec1809c1b5a680eb7389"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.15"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.SymbolicIndexingInterface]]
deps = ["DocStringExtensions"]
git-tree-sha1 = "f8ab052bfcbdb9b48fad2c80c873aa0d0344dfe5"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.2.2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "1544b926975372da01227b382066ab70e574a3ec"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TerminalLoggers]]
deps = ["LeftChildRightSiblingTrees", "Logging", "Markdown", "Printf", "ProgressLogging", "UUIDs"]
git-tree-sha1 = "f53e34e784ae771eb9ccde4d72e578aa453d0554"
uuid = "5d786b92-1e48-4d6f-9151-6b4477ca9bed"
version = "0.1.6"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[deps.TruncatedStacktraces]]
deps = ["InteractiveUtils", "MacroTools", "Preferences"]
git-tree-sha1 = "7bc1632a4eafbe9bd94cf1a784a9a4eb5e040a91"
uuid = "781d530d-4396-4725-bb49-402e4bee1e77"
version = "1.3.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.4.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╟─acb4555e-969b-4ee7-a4af-7341a9eb5388
# ╠═3fa1d138-6e8e-4e8b-bfac-71536628eeb8
# ╠═c5915064-60e6-4180-a4e9-8e8a4e91b020
# ╠═4bdd0dcd-ca89-4102-bfa9-926683fee155
# ╠═f03679e5-5d9e-41e5-bff2-c02822181d01
# ╠═22433e08-4ab4-4a23-b079-5b73b9ae6128
# ╠═6115a5f1-6d34-4c10-985d-6abe36275978
# ╠═6d0e158d-ba36-4100-86bf-44b878b30356
# ╠═58165c5e-b292-4b54-90a2-24b911095af7
# ╠═27ebaf90-bdc4-408b-9b7a-c951d3a64c8c
# ╠═c7d1204a-8edf-4f36-b9f9-dc6e08477a0b
# ╟─e0ea9f28-bafc-4566-9b22-d00a2253d9e9
# ╠═3f22a7ae-bd49-478c-8f74-391bb6cf11cc
# ╟─3d0d0368-031d-4a04-b66c-2dc5e8be00a0
# ╠═ea815f0c-8e7e-4b9d-a765-34baf0242140
# ╠═9257a65d-7dd1-41c3-8071-19ecf9115797
# ╠═8412b028-a559-4566-bd51-c4650a8edf73
# ╠═63d598fa-02a6-4d36-94f4-43831a5de8d1
# ╠═a5db525e-1ee9-4451-a933-c3041166e38a
# ╟─25355d27-0766-468d-9c7c-edf0ee743711
# ╠═ff8ded6f-6f7d-41ac-93a0-11ff1f6f2a40
# ╟─29faf78f-a44f-48cc-9e07-80cc70f6764c
# ╠═79ede060-9bf1-4a71-a92b-493b9d4fce8e
# ╟─a53461db-00d3-48da-9a03-116311c10b5a
# ╠═4a97d36d-81f6-447f-ba26-6f0ebb93217c
# ╟─ae16f334-e583-4fac-8c34-c5b4e60f248f
# ╠═0340001b-8282-4fb7-94a1-cfec5c2ecfb6
# ╟─b923b0fd-f373-48b0-8689-0bdef2780c54
# ╠═0e679fb7-1baf-4545-aef5-eb564e41db54
# ╟─eab52f13-6ff0-4fbc-80c9-782ef03b6e7a
# ╠═c4d2d970-c468-4d18-852f-846cb81a2d7a
# ╟─17e4ff5b-ddd6-404f-a092-4c7c9b18cfed
# ╠═337a4039-2349-454e-b6dc-6a8d584b58a9
# ╟─6c8f8970-4ff3-4b7a-b537-970cd6055e59
# ╠═b51f9964-1e19-4078-a2c6-6109e935a000
# ╠═66acd240-f950-4c2a-bc06-1ac2c5929544
# ╟─fd5c3705-a79e-4898-a94c-6ceb966a1334
# ╠═bd06ef56-c099-4631-b895-0fa68da0f8ff
# ╟─04c2526e-b991-43f0-aea3-ff816a2bc9de
# ╠═90757798-7aa5-46e8-8c7b-d7c66b47b865
# ╟─2c648777-a967-4129-8640-504fd523852f
# ╠═52baa97e-dcd4-4ba7-8492-6f1179522562
# ╟─4fe4e530-813d-4f8f-8a74-de08de26c3aa
# ╠═d741b31f-e947-4650-bcba-9d9b8f842726
# ╠═dc57e188-20f6-4c7e-bef0-955547f2482f
# ╟─52735849-5810-46d6-bfa6-7fc67ba8c1c3
# ╠═719aafc6-9a82-4b22-ae96-0ba843327c0a
# ╠═1d5d7187-fbac-4d4f-8a02-31f6251fcd72
# ╠═31766e3e-1d86-4d2a-8330-9838283d2f90
# ╠═cdba5bb2-d52b-41d6-85ff-4011fc570a11
# ╠═7cafbcf6-57d4-4f07-87e7-74504e98d4f3
# ╠═67fc7546-e287-4001-a0cd-d5f74a94f3bc
# ╠═30b8cec9-3c00-49ea-bf9f-76fe26fe5a87
# ╠═15ca9bd4-8ced-462b-b34f-b781a041c1f1
# ╠═f0ede4eb-1811-48e7-9a2b-49e7f67ae7a8
# ╠═708951df-5d62-4e06-9493-9886f95e426d
# ╠═6e6eac98-7825-467a-bd59-ee33ec66c321
# ╠═88801de8-abd8-4306-8504-04edbf2ee518
# ╠═53f5d11d-7f29-48ad-a9be-d6ab67b763f0
# ╠═b0ff9d1d-82fd-4d85-a976-2182c7ce0833
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
