### A Pluto.jl notebook ###
# v0.19.11

using Markdown
using InteractiveUtils

# ╔═╡ f21df0d4-cbb7-4016-8c04-5df623360803

# ╔═╡ 37bce0f8-1dfd-11ed-27ea-5b820b6b7850
using AccessorsExtra

# ╔═╡ 426833f5-4bae-4e8f-af38-5b979962f294
using DataPipes

# ╔═╡ 4f7546dc-e465-4cdc-8c5a-17fdb6875f04
using DisplayAs: Text as AsText

# ╔═╡ 33c41f64-4cf5-4ec1-aa65-5fcb97d936da
using StructArrays

# ╔═╡ 77dcc848-0bf3-4a65-8cda-fd5942ea5973
using SplitApplyCombine

# ╔═╡ 27f543d7-58b9-44b9-a411-c88152c2b473
using AxisKeys

# ╔═╡ 87c909b3-af7e-49e5-b92f-74c6d89356bf
using Distributions

# ╔═╡ e0e83090-ebff-41af-9f43-8fa15e90175e
using RectiGrids

# ╔═╡ 1a4affaa-465d-4bdd-9f79-b9fc09e4ce21
using PyPlotUtils

# ╔═╡ e8983922-5f1c-4696-b3dc-b84135bb66b1
using StaticArrays

# ╔═╡ e003c366-a162-4575-97ab-9540c8b1b459
md"""
!!! info "AccessorsExtra.jl"
	`AccessorsExtra` provides Accessors.jl integrations with lots of third-party packages, and implements additional optics.

The [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl) package defines a unified interface to modify immutable data structures. See its docs for details and background.

`AccessorsExtra.jl` defines more optics, focusing on those that operate on types defined in other packages. It also implements several more general optics, not tied to particular types. They are somewhat too opinionated to be included into a package as foundational as `Accessors` itself.

`AccessorsExtra.jl` heavily relies on `Requires.jl` to make all dependencies optional. By necessity, we engage in type piracy here by defining methods of `Accessors.jl` functions for other packages' types. The only way around would be for all those packages to depend on `Accessors`, which is infeasible.

This notebook showcases some functionality defined in `AccessorsExtra`, but is by no means complete. The full list of implemented optics can be seen in the sources code, and their usage should be intuitive. Specifically, all `set` methods obey the common lens laws, for example `optic(set(obj, optic, val)) == val`.

Integrations with other -- reasonably common -- packages are also in scope for `AccessorsExtra.jl`.
"""

# ╔═╡ 5ea94011-6019-47aa-9228-1df5af684d77
md"""
# Examples
"""

# ╔═╡ a2b3ee98-080b-43df-9748-8dd2b7c83135
md"""
First, some **general features that work for various types**.

Modify keys, values, or `pairs` of a collection --- more specific than `Accessors.Elements()`, work similarly to it:
"""

# ╔═╡ a25ed375-9127-4e7e-9369-54a5900c2c42
dct = Dict("a" => 1, "b" => 2)

# ╔═╡ eb3d938d-4660-47ce-b16e-443d5c4d9d54
@modify(k -> k^3, dct |> Keys())

# ╔═╡ d9dca90e-b424-4d9f-b89c-e1481b5a23d2
@modify(dct |> Pairs()) do (k, v)
	k => (k, v)
end

# ╔═╡ 021217dd-3c02-4043-a7d1-cda07b434fa3
arr = [:a, :b, :c]

# ╔═╡ 8025f34a-964e-4242-b882-37b77f97c8c8
@modify(arr |> Pairs()) do (k, v)
	k => (k, v)
end

# ╔═╡ ed272917-5d8b-483c-96c7-78beabff6fef
md"""
`replace` one component (for example, a field) with another:
"""

# ╔═╡ 63ac4bc8-b42b-4d77-ba6c-c2a13da61977
ntup = (a=1, b=2, c=3)

# ╔═╡ d3c72bd3-7dcd-4dc3-86c8-ad1b37bf84d7
@replace ntup.d = _.b

# ╔═╡ 290dfedd-ff44-495f-b25a-213372891cb5


# ╔═╡ f2b4453c-6955-49c8-97ae-e45cd2788a0e
md"""
**`StaticArrays.jl` integration**:
"""

# ╔═╡ bd65eeb5-7c3f-4975-874d-948c938b7a56
sv = SVector(1, 2, 3)

# ╔═╡ 0db80bc0-bc94-4c80-8149-6b92d28ec5d1
@set sv[1] = -123

# ╔═╡ 8798f5ca-9b09-4251-9e5f-849bb6062891
@set sv.data = (1., 2., 3)

# ╔═╡ bd3b5f76-0d7f-4c1b-af7d-410f18f8fdf7
@set sv.data = (1., 2.)

# ╔═╡ c1208386-200b-4e5e-9f6f-3a43c28e7ae0
@set sv.y = -123

# ╔═╡ 4cd15ace-8418-4118-ba69-23f6c3bc7331

# ╔═╡ b27270bd-63c3-41e2-a81c-06857f133282


# ╔═╡ 3524e098-d91e-4d71-b730-19e0fb768f90
md"""
**`AxisKeys.jl` intergration**: modify axis keys, dimension names, or content.
"""

# ╔═╡ 49e27844-311c-40a7-a74e-c0eb7a8694f3
md"""
Suppose you have a keyed array with two axes:
"""

# ╔═╡ 1394b5a1-a496-41cd-9141-bb5842665414
A = @p grid(x=range(0, 30; length=101), y=range(0, 50; length=101)) |>
	map(sin(_.x) * _.y);

# ╔═╡ 16cd3f89-ee42-4e0c-8028-e45d771128cf
A |> AsText

# ╔═╡ c11aa5bf-aff4-4abf-bc6c-7482424a2678
named_axiskeys(A)

# ╔═╡ 5fd99fb6-3e3d-4043-b95e-f4037aaec20f
begin
	plt.figure()
	imshow_ax(A)
	plt.colorbar()
	plt.gcf()
end

# ╔═╡ ab85b270-f0b1-4fa0-a2d5-686ef415f4bd
md"""
We can center it at zero by subtracting the mean key for each axis:
"""

# ╔═╡ b4b71927-e93c-408c-8fb5-9665422a0048
B = @modify(x -> x .- mean(x), A |> axiskeys |> Elements());

# ╔═╡ b9a40335-c1e9-46b6-93dc-f7d3cb5fa6b3
named_axiskeys(B)

# ╔═╡ cb98a0f4-9c7b-4560-b8d2-4af39ef43fa2
md"""
Values stay the same, only the axes change:
"""

# ╔═╡ d8af0dc1-668c-4329-8017-fcc340d8e11d
begin
	plt.figure()
	imshow_ax(B)
	plt.colorbar()
	plt.gcf()
end

# ╔═╡ 454eb343-c969-43c8-b61e-8f195fc04cb6
md"""
Alternatively, we can set the content keeping axes the same:
"""

# ╔═╡ 517e95c4-e855-49d4-b094-fc3f6dbfb4e1
C = @set vec(A) = 1:length(A);

# ╔═╡ 7d0ebe6e-8c3e-4b33-a26e-78fdfafa6c0b
begin
	plt.figure()
	imshow_ax(C)
	plt.colorbar()
	plt.gcf()
end

# ╔═╡ 1384b245-1d02-4487-9479-17a2d556977e


# ╔═╡ 2c50c8f7-fe84-4e0f-b884-fd87385d9ddb
md"""
**`StructArrays.jl` integration**: set/insert/delete array fields.
"""

# ╔═╡ 892766bf-7a11-4c88-ae17-2b66362af0a5
sa = StructArray(a=[1, 2, 3], b=[:x, :y, :z])

# ╔═╡ eebb83b2-5e58-47d2-a5d5-9d01d9d91242
@set sa.a *= 2

# ╔═╡ 42f0f89a-c937-4801-b409-06f9d3b8d677
@insert sa.c = sa.a .+ 1

# ╔═╡ 50ca4786-5097-40fa-bf77-74bc0d9ed7d1
@replace sa.c = sa.a

# ╔═╡ 7be3cc08-73fb-4952-ac20-ad2acf87d990


# ╔═╡ 679a21cb-5365-4231-89f4-cb3c5a6b3d75
md"""
**`SplitApplyCombine.jl` integration**: support `setindex!` for `mapview`.
"""

# ╔═╡ 8f38060d-9469-4b3c-82ea-b9430c1ec246
paths = [(;a, b=rand()) for a in 1:5]

# ╔═╡ 6496f6a5-e5b0-4ca8-86fa-10bd7e5ebdd7
bnames = mapview(@optic(_.a ^ 2), paths)

# ╔═╡ 1ab89299-f8fc-4170-94af-ccd6d3c1a3c6
bnames[1] = 100

# ╔═╡ 6c85e92c-453e-48c5-b6e9-79e84d96f9ff
md"""
`setindex!` propagates to the parent array:
"""

# ╔═╡ 5f6481b5-64a0-4fd1-81a6-901b1c97574e
paths

# ╔═╡ 2b86b679-66f5-404c-98a7-acd1b515c6c1
md"""
If the mapping function is invertible, `push!` is also supported:
"""

# ╔═╡ bdb03d1b-dfb8-48b2-9319-58281371f270
xs = [-2, 0., 1, 2]

# ╔═╡ 83d276a2-ce85-45b3-bdcf-12a6b3c740c0
ys = mapview(@optic(cdf(Normal(), _)), xs)

# ╔═╡ 5bfcf99f-15ae-4fa1-b2be-5e149a770f87
push!(ys, 1 - 1e-5)

# ╔═╡ e67ea5b3-b198-4db3-8562-cc789efff697
xs

# ╔═╡ 5b27fb24-7df8-4089-b989-93634808b7c5


# ╔═╡ 2ab78c2f-7cae-41e2-92ba-1ed5fe908fa3


# ╔═╡ 5e913a04-03d8-483b-b0c6-95dbf1b6de59


# ╔═╡ f7925b57-c3cf-407f-854c-321f1de61970
md"""
Package imports below:
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AccessorsExtra = "33016aad-b69d-45be-9359-82a41f556fd4"
AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
DataPipes = "02685ad9-2d12-40c3-9f73-c6aeda6a7ff5"
DisplayAs = "0b91fe84-8a4c-11e9-3e1d-67c38462b6d6"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
PyPlotUtils = "5384e752-6c47-47b3-86ac-9d091b110b31"
RectiGrids = "8ac6971d-971d-971d-971d-971d5ab1a71a"
SplitApplyCombine = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"

[compat]
AccessorsExtra = "~0.1.9"
AxisKeys = "~0.2.7"
ConstructionBase = "~1.4.1"
DataPipes = "~0.2.17"
DisplayAs = "~0.1.6"
Distributions = "~0.25.68"
PyPlotUtils = "~0.1.15"
RectiGrids = "~0.1.12"
SplitApplyCombine = "~1.2.2"
StaticArrays = "~1.5.6"
StructArrays = "~0.6.12"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.0"
manifest_format = "2.0"
project_hash = "e3b96de707b531e1eb6575438048875d3b8591a2"

[[deps.AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "69f7020bd72f069c219b5e8c236c1fa90d2cb409"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.2.1"

[[deps.Accessors]]
deps = ["Compat", "CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "LinearAlgebra", "MacroTools", "Requires", "Test"]
git-tree-sha1 = "8557017cfc7b58baea05a43ed35538857e6d35b4"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.19"

[[deps.AccessorsExtra]]
deps = ["Accessors", "ConstructionBase", "InverseFunctions", "Reexport", "Requires"]
git-tree-sha1 = "ef45a3c71f3a7e98a107ec66222e04250185c7bb"
uuid = "33016aad-b69d-45be-9359-82a41f556fd4"
version = "0.1.9"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "195c5505521008abea5aee4f96930717958eac6f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.4.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.AxisKeys]]
deps = ["AbstractFFTs", "ChainRulesCore", "CovarianceEstimation", "IntervalSets", "InvertedIndices", "LazyStack", "LinearAlgebra", "NamedDims", "OffsetArrays", "Statistics", "StatsBase", "Tables"]
git-tree-sha1 = "88cc6419032d0e3ea69bc65d012aa82302774ab8"
uuid = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
version = "0.2.7"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "80ca332f6dcb2508adba68f22f551adb2d00a624"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.3"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "38f7a08f19d8810338d4f5085211c7dfa5d5bdd8"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.4"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "5856d3031cdb1f3b2b6340dfdc66b6d9a149a374"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.2.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "0.5.2+0"

[[deps.CompositeTypes]]
git-tree-sha1 = "d5b014b216dc891e81fea299638e4c10c657b582"
uuid = "b152e2b5-7a66-4b01-a709-34e65c35f657"
version = "0.1.2"

[[deps.CompositionsBase]]
git-tree-sha1 = "455419f7e328a1a2493cabc6428d79e951349769"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.1"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "6e47d11ea2776bc5627421d59cdcc1296c058071"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.7.0"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "fb21ddd70a051d882a1686a5a550990bbe371a95"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.4.1"

[[deps.CovarianceEstimation]]
deps = ["LinearAlgebra", "Statistics", "StatsBase"]
git-tree-sha1 = "3c8de95b4e932d76ec8960e12d681eba580e9674"
uuid = "587fd27a-f159-11e8-2dae-1979310e6154"
version = "0.2.8"

[[deps.DataAPI]]
git-tree-sha1 = "fb5f5316dd3fd4c5e7c30a24d50643b73e37cd40"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.10.0"

[[deps.DataPipes]]
deps = ["Accessors", "SplitApplyCombine"]
git-tree-sha1 = "ab6b5bf476e9111b0166cc3f8373638204d7fafd"
uuid = "02685ad9-2d12-40c3-9f73-c6aeda6a7ff5"
version = "0.2.17"

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

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.Dictionaries]]
deps = ["Indexing", "Random", "Serialization"]
git-tree-sha1 = "96dc5c5c8994be519ee3420953c931c55657a3f2"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.3.24"

[[deps.DirectionalStatistics]]
deps = ["AccessorsExtra", "IntervalSets", "InverseFunctions", "LinearAlgebra", "Statistics", "StatsBase"]
git-tree-sha1 = "156365de4369a6cf587d0d59ce52fe688f2b5f92"
uuid = "e814f24e-44b0-11e9-2fd5-aba2b6113d95"
version = "0.1.19"

[[deps.DisplayAs]]
git-tree-sha1 = "43c017d5dd3a48d56486055973f443f8a39bb6d9"
uuid = "0b91fe84-8a4c-11e9-3e1d-67c38462b6d6"
version = "0.1.6"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "334a5896c1534bb1aa7aa2a642d30ba7707357ef"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.68"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "5158c2b41018c5f7eb1470d558127ac274eca0c9"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.1"

[[deps.DomainSets]]
deps = ["CompositeTypes", "IntervalSets", "LinearAlgebra", "Random", "StaticArrays", "Statistics"]
git-tree-sha1 = "dc45fbbe91d6d17a8e187abad39fb45963d97388"
uuid = "5b8099bc-c8ec-5219-889f-1d9e522a28bf"
version = "0.5.13"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "246621d23d1f43e3b9c368bf3b72b2331a27c286"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.2"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions", "Test"]
git-tree-sha1 = "709d864e3ed6e3545230601f94e11ebc65994641"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.11"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IntervalSets]]
deps = ["Dates", "Random", "Statistics"]
git-tree-sha1 = "076bb0da51a8c8d1229936a1af7bdfacd65037e1"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.2"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "b3364212fb5d870f724876ffcd34dd8ec6d98918"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.7"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LazyStack]]
deps = ["ChainRulesCore", "LinearAlgebra", "NamedDims", "OffsetArrays"]
git-tree-sha1 = "2eb4a5bf2eb0519ebf40c797ba5637d327863637"
uuid = "1fad7336-0346-5a1a-a56f-a06ba010965b"
version = "0.0.8"

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

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "94d9c52ca447e23eac0c0f074effbcd38830deb5"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.18"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "a7c3d1da1189a1c2fe843a3bfa04d18d20eb3211"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.1"

[[deps.NamedDims]]
deps = ["AbstractFFTs", "ChainRulesCore", "CovarianceEstimation", "LinearAlgebra", "Pkg", "Requires", "Statistics"]
git-tree-sha1 = "f39537cbe1cf4f407e65bdf7aca6b04f5877fbb1"
uuid = "356022a1-0364-5f58-8944-0da4b18d706f"
version = "1.1.0"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.NonNegLeastSquares]]
deps = ["Distributed", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "1271344271ffae97e2855b0287356e6ea5c221cc"
uuid = "b7351bd1-99d9-5c5d-8786-f205a815c4d7"
version = "0.4.0"

[[deps.OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "1ea784113a6aa054c5ebd95945fa5e52c2f378e7"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.12.7"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "cf494dca75a69712a72b80bc48f59dcf3dea63ec"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.16"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "0044b23da09b5608b4ecacb4e5e6c6332f833a7e"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.3.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "53b8b07b721b77144a0fbbbc2675222ebf40a02d"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.94.1"

[[deps.PyPlot]]
deps = ["Colors", "LaTeXStrings", "PyCall", "Sockets", "Test", "VersionParsing"]
git-tree-sha1 = "f9d953684d4d21e947cb6d642db18853d43cb027"
uuid = "d330b81b-6aea-500a-939a-2ce795aea3ee"
version = "2.11.0"

[[deps.PyPlotUtils]]
deps = ["Accessors", "AxisKeys", "Colors", "DataPipes", "DirectionalStatistics", "DomainSets", "IntervalSets", "LinearAlgebra", "NonNegLeastSquares", "PyCall", "PyPlot", "StatsBase", "Unitful"]
git-tree-sha1 = "ff89807874ac84dad041d9bc30bd3c9cdfaab241"
uuid = "5384e752-6c47-47b3-86ac-9d091b110b31"
version = "0.1.15"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RectiGrids]]
deps = ["AxisKeys", "ConstructionBase", "Random", "StaticArraysCore"]
git-tree-sha1 = "5892b3551d6bea70066434ade9628fe2e176191b"
uuid = "8ac6971d-971d-971d-971d-971d5ab1a71a"
version = "0.1.12"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "d75bda01f8c31ebb72df80a46c88b25d1c79c56d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.7"

[[deps.SplitApplyCombine]]
deps = ["Dictionaries", "Indexing"]
git-tree-sha1 = "48f393b0231516850e39f6c756970e7ca8b77045"
uuid = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"
version = "1.2.2"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "dfec37b90740e3b9aa5dc2613892a3fc155c3b42"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.6"

[[deps.StaticArraysCore]]
git-tree-sha1 = "ec2bd695e905a3c755b33026954b119ea17f2d22"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.3.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f9af7f195fb13589dd2e2d57fdb401717d2eb1f6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.5.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "HypergeometricFunctions", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "5783b877201a82fc0014cbf381e7e6eb130473a4"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.0.1"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArraysCore", "Tables"]
git-tree-sha1 = "8c6ac65ec9ab781af05b08ff305ddc727c25f680"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.12"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Unitful]]
deps = ["ConstructionBase", "Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "b649200e887a487468b71821e2644382699f1b0f"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.11.0"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"

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
# ╟─e003c366-a162-4575-97ab-9540c8b1b459
# ╟─5ea94011-6019-47aa-9228-1df5af684d77
# ╟─a2b3ee98-080b-43df-9748-8dd2b7c83135
# ╠═a25ed375-9127-4e7e-9369-54a5900c2c42
# ╠═eb3d938d-4660-47ce-b16e-443d5c4d9d54
# ╠═d9dca90e-b424-4d9f-b89c-e1481b5a23d2
# ╠═021217dd-3c02-4043-a7d1-cda07b434fa3
# ╠═8025f34a-964e-4242-b882-37b77f97c8c8
# ╟─ed272917-5d8b-483c-96c7-78beabff6fef
# ╠═63ac4bc8-b42b-4d77-ba6c-c2a13da61977
# ╠═d3c72bd3-7dcd-4dc3-86c8-ad1b37bf84d7
# ╠═290dfedd-ff44-495f-b25a-213372891cb5
# ╟─f2b4453c-6955-49c8-97ae-e45cd2788a0e
# ╠═bd65eeb5-7c3f-4975-874d-948c938b7a56
# ╠═0db80bc0-bc94-4c80-8149-6b92d28ec5d1
# ╠═8798f5ca-9b09-4251-9e5f-849bb6062891
# ╠═bd3b5f76-0d7f-4c1b-af7d-410f18f8fdf7
# ╠═c1208386-200b-4e5e-9f6f-3a43c28e7ae0
# ╠═f21df0d4-cbb7-4016-8c04-5df623360803
# ╠═4cd15ace-8418-4118-ba69-23f6c3bc7331
# ╠═b27270bd-63c3-41e2-a81c-06857f133282
# ╟─3524e098-d91e-4d71-b730-19e0fb768f90
# ╟─49e27844-311c-40a7-a74e-c0eb7a8694f3
# ╠═1394b5a1-a496-41cd-9141-bb5842665414
# ╠═16cd3f89-ee42-4e0c-8028-e45d771128cf
# ╠═c11aa5bf-aff4-4abf-bc6c-7482424a2678
# ╟─5fd99fb6-3e3d-4043-b95e-f4037aaec20f
# ╟─ab85b270-f0b1-4fa0-a2d5-686ef415f4bd
# ╠═b4b71927-e93c-408c-8fb5-9665422a0048
# ╠═b9a40335-c1e9-46b6-93dc-f7d3cb5fa6b3
# ╟─cb98a0f4-9c7b-4560-b8d2-4af39ef43fa2
# ╟─d8af0dc1-668c-4329-8017-fcc340d8e11d
# ╟─454eb343-c969-43c8-b61e-8f195fc04cb6
# ╠═517e95c4-e855-49d4-b094-fc3f6dbfb4e1
# ╟─7d0ebe6e-8c3e-4b33-a26e-78fdfafa6c0b
# ╠═1384b245-1d02-4487-9479-17a2d556977e
# ╟─2c50c8f7-fe84-4e0f-b884-fd87385d9ddb
# ╠═892766bf-7a11-4c88-ae17-2b66362af0a5
# ╠═eebb83b2-5e58-47d2-a5d5-9d01d9d91242
# ╠═42f0f89a-c937-4801-b409-06f9d3b8d677
# ╠═50ca4786-5097-40fa-bf77-74bc0d9ed7d1
# ╠═7be3cc08-73fb-4952-ac20-ad2acf87d990
# ╟─679a21cb-5365-4231-89f4-cb3c5a6b3d75
# ╠═8f38060d-9469-4b3c-82ea-b9430c1ec246
# ╠═6496f6a5-e5b0-4ca8-86fa-10bd7e5ebdd7
# ╠═1ab89299-f8fc-4170-94af-ccd6d3c1a3c6
# ╟─6c85e92c-453e-48c5-b6e9-79e84d96f9ff
# ╠═5f6481b5-64a0-4fd1-81a6-901b1c97574e
# ╟─2b86b679-66f5-404c-98a7-acd1b515c6c1
# ╠═bdb03d1b-dfb8-48b2-9319-58281371f270
# ╠═83d276a2-ce85-45b3-bdcf-12a6b3c740c0
# ╠═5bfcf99f-15ae-4fa1-b2be-5e149a770f87
# ╠═e67ea5b3-b198-4db3-8562-cc789efff697
# ╠═5b27fb24-7df8-4089-b989-93634808b7c5
# ╠═2ab78c2f-7cae-41e2-92ba-1ed5fe908fa3
# ╠═5e913a04-03d8-483b-b0c6-95dbf1b6de59
# ╟─f7925b57-c3cf-407f-854c-321f1de61970
# ╠═37bce0f8-1dfd-11ed-27ea-5b820b6b7850
# ╠═426833f5-4bae-4e8f-af38-5b979962f294
# ╠═4f7546dc-e465-4cdc-8c5a-17fdb6875f04
# ╠═33c41f64-4cf5-4ec1-aa65-5fcb97d936da
# ╠═77dcc848-0bf3-4a65-8cda-fd5942ea5973
# ╠═27f543d7-58b9-44b9-a411-c88152c2b473
# ╠═87c909b3-af7e-49e5-b92f-74c6d89356bf
# ╠═e0e83090-ebff-41af-9f43-8fa15e90175e
# ╠═1a4affaa-465d-4bdd-9f79-b9fc09e4ce21
# ╠═e8983922-5f1c-4696-b3dc-b84135bb66b1
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
