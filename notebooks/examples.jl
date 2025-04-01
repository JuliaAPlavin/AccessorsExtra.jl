### A Pluto.jl notebook ###
# v0.20.6

using Markdown
using InteractiveUtils

# ╔═╡ 8f657eb5-ff7f-4d0c-a9ff-967f30871b6b
using AccessorsExtra

# ╔═╡ a0313d3a-73a5-4a0a-92e0-1f862e95cb70
using BenchmarkTools

# ╔═╡ 433ef25f-23fe-4646-8168-0c03a02cca69
using PlutoUI

# ╔═╡ e003c366-a162-4575-97ab-9540c8b1b459
md"""
!!! info "AccessorsExtra.jl"
	Advanced optics/lenses and relevant tools, based on the `Accessors.jl` framework.

The [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl) package defines a unified interface to modify immutable data structures --- so-called optics or lenses. See its docs for details and background. \
`AccessorsExtra.jl` defines more optics and relevant tools that are considered too experimental or opinionated to be included into a package as foundational as `Accessors` itself.

This notebook showcases the stable and widely applicable pieces of functionality defined in `AccessorsExtra`. See the source code and tests for more.

Optics and operations in `AccessorsExtra` attempt to have as little overhead as possible, often zero, with tests checking this.
"""

# ╔═╡ 5ea94011-6019-47aa-9228-1df5af684d77
md"""
# Examples
"""

# ╔═╡ 67906fcb-6a41-47df-b64b-aab148d455c8
md"""
## Multi-optics
### Concatenated

Concatenate multiple optics together, to form an optic that references multiple values in different locations within the object.

Use the `@optics` macro or the `++` operator:
"""

# ╔═╡ 91c72a11-a77d-456a-beeb-7e3e690828ae
obj = (a=1, b=[2, 3], c=[4, 5])

# ╔═╡ 69fe774a-059d-46db-9a30-9b07679eeef5
multiopt = @optics _.a _.c[∗]

# ╔═╡ e1e39d1e-c273-4589-8bbc-8795190bbf4a
multiopt === @o(_.a) ++ @o(_.c[∗])

# ╔═╡ 118b07f9-cb3d-4ae8-86c4-9b78e7746707
getall(obj, multiopt)

# ╔═╡ 51e80a70-e931-478f-8bc4-2c45b12121af
modify(string, obj, multiopt)

# ╔═╡ 1ac43bdd-b707-4dbf-837f-3bda46673854
md"""
### Containers

Create non-scalar optics that reference a container (tuple/array/...) built from arbitrary parts of the object.

Use the `@optic₊` macro. This functionality can potentially be put into the upstream `@optic` macro.
"""

# ╔═╡ 83255b2f-18d8-4938-ab26-4a07630eddbe
nt_opt = @optic₊ (a=_.a, c_first=_.c[1], c_second=_.c[2])

# ╔═╡ bb5ebb98-3c10-446b-b2c5-39cf271c6ba7
nt_opt(obj)

# ╔═╡ dc5bca1f-8ebb-4192-bd8a-eb08dfb91ac3
vec_opt = @optic₊ [_.a, _.c[1], _.c[2]]

# ╔═╡ 02b0cabf-0991-417b-8ec5-c8db1862fa08
set(obj, vec_opt, [:x, :y, :z])

# ╔═╡ 29684b6c-f786-4131-9073-daaa0a33d8e2
md"""
## Recursive optics

Efficient fully-featured recursive optics!

The upstream `Accessors` provides the `Recursive` optic, but:
- it either selects an element or recurses into it, cannot leave intact;
- it only support `modify` --- no `getall`, no `setall`;
- `modify` often doesn't infer, leading to a high overhead.
"""

# ╔═╡ 23a5243e-1b56-4c44-8f0e-676781ce1b1e
objr = (a=1, b=(2, "3"), c=("4", 5))

# ╔═╡ 83a07b18-e186-4c0d-bc0d-216b3dda7800
orec_orig = Recursive(x -> x isa Union{Tuple,NamedTuple}, Elements())

# ╔═╡ 44c133ff-3c88-42d0-bf9a-a0214fb3d0c9
@btime modify(x -> x isa Number ? -x : x, $objr, $orec_orig)

# ╔═╡ b65e39ab-8a57-4498-bddf-bd64208fd2c6
getall(objr, orec_orig)

# ╔═╡ 3d9451ce-81c5-4244-a524-bf233e1de521
md"""
In `AccessorsExtra`, we provide a flexible and well-optimized `RecursiveOfType` optic. \
All operations with `RecursiveOfType` are type-stable and efficient:
"""

# ╔═╡ 51e48f24-4ad9-47fc-98fe-2e65826d0cdc
orec = RecursiveOfType(Number)

# ╔═╡ 06f8917b-8542-4d37-8b71-44475a2f663a
@btime getall($objr, $orec)

# ╔═╡ edd6da10-3cd1-4b70-9c4c-e15603b7f6a2
@btime modify(-, $objr, $orec)

# ╔═╡ 08adc947-2c30-43cc-8138-d126c81e76a3
@btime setall($objr, $orec, (10, 20, 30))

# ╔═╡ c7eb40e1-e18a-4640-8d86-5f3a1ce4c23f
md"""
`RecursiveOfType` is fully composable with other optics:
"""

# ╔═╡ eec65f2e-4a80-4c11-8ad9-a6c93a468912
@btime modify(xs -> xs ./ sum(xs), $objr, $orec ⨟ PartsOf())

# ╔═╡ cc5c1ee4-20aa-4324-b0e9-0f8db492e72c
md"""
## Optional optics: `maybe()` and `@oget`

Optional optics: reference a value that may or may not be present in the object. If not present, `modify()` doesn't do anything, and calling the optic returns `nothing`.

Use the `maybe()` function to create such an optic:
"""

# ╔═╡ b3ffef81-13e2-40ef-bb03-71c51f36f47e
o_mb = maybe(@o _[2]) ∘ @o(_.a)

# ╔═╡ 269a5a37-d4bf-4ba0-a59b-aa628e47ff3b
o_mb((a=[1, 2],))

# ╔═╡ c5791834-27fc-453f-9305-cb977a046d28
o_mb((a=[1],))

# ╔═╡ 2f0f1190-2377-4b30-9e71-c9d8b3b5f4ec
modify(-, (a=[1, 2],), o_mb)

# ╔═╡ 10e5512f-df3b-49e9-bf03-222c05a1933a
modify(-, (a=[1],), o_mb)

# ╔═╡ 05a6de1b-fc64-43b5-b7e9-49789a893272
md"""
The `@oget` macro provides a more convenient way to access data that may or may not be present. It stops when encountering a non-existing value or `nothing`:
"""

# ╔═╡ 4fc97cf0-7045-4ce1-b7ce-8faaa1fc484d
@oget obj.b[1]

# ╔═╡ 841afae0-303a-4e1a-b1d8-b33c54787a02
# returns nothing
@oget obj.d.e

# ╔═╡ 15e23d42-4215-4a9a-ab1e-7c036e77835b
# returns the first existing value among several arguments
@oget obj.d.e obj.b[1]

# ╔═╡ d375ae9f-2530-44bc-bd93-2c89e9c58e2a
md"""
## Verbose optics: `logged()`

Wrap any optic with `logged()` to log all steps recursively:
"""

# ╔═╡ 20350429-74ae-475b-baee-2528fd77e4c4
getall(obj, logged(multiopt))

# ╔═╡ bf9f7247-8aa2-4fc8-974a-65ba71021f96
md"""
## `construct()` an object from optics

This is mostly considerend an interface for generalized object construction, to be implemented by type authors when needed.

`AccessorsExtra` itself defines:
- the underlying machinery: stuff like `@construct` macro or invertible function preprocessing
- `construct` implementation for common types like tuples/vectors/svectors/...; see `methods(construct)` for a complete list.
"""

# ╔═╡ c09d4e9c-2d64-4638-9774-0697989b00b0
construct(Complex, @o(_.re) => 1, @o(_.im) => 2)

# ╔═╡ ab7eb768-3dcc-491d-acd2-04ae572d7938
construct(Complex, @o(log10(_.re)) => 1, @o(_.im) => 2)

# ╔═╡ 102baa65-088f-4d45-882c-b293d2f0e279
construct(Vector, only => 1)

# ╔═╡ ccdc9876-95f2-4fd2-8ff0-fefe1f0f96a7
md"""
## Optics for `keys()`, `values()`, `pairs()`

Use these functions as optics:
"""

# ╔═╡ 5be7b8b2-9568-4d80-96be-fcbd0c68b16a
dct = Dict(4 => 5, 6 => 7)

# ╔═╡ a6b8c4fc-9555-4ddc-a2d8-9c2c4e65344e
modify(x -> x+1, dct, @o values(_)[∗])

# ╔═╡ a3387faf-20df-4f3d-bf6c-f0e409ded011
modify(x -> x+1, dct, @o keys(_)[∗])

# ╔═╡ 06690850-de63-4217-b619-8838f524bcc5
modify(((i, x),) -> 2i => i + x, dct, @o pairs(_)[∗])

# ╔═╡ 2fe6a54a-e914-430b-9703-a48ad172b0bf
md"""
## ... and more!

The following isn't documented, see packages tests for usage examples:
- `@optic` macro extended
- `onget`/`onset`/`ongetset` handlers
- `modifying(optic)`: interface to constrain modification
- optics with context, eg `keyed(Elements())`
- `FlexIx` grow/shrink collections
- `⩓` and `⩔` function operators
- `PartsOf()` all optic values together
- regular expressions as optics
- `@o view(_, ix)` modifies the input array
- `set(1:5, last, 10) == 1:10`
- `funcvallens`/`FuncResult`/`FuncArgument` optics
- `get_steps`
- `@replace`
"""

# ╔═╡ c4fe8f56-2287-4fee-8c27-f23a2a3c4c40


# ╔═╡ 10fd2a3e-924b-48fc-a126-fe5f33ecedc3
TableOfContents()

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AccessorsExtra = "33016aad-b69d-45be-9359-82a41f556fd4"
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
AccessorsExtra = "~0.1.95"
BenchmarkTools = "~1.6.0"
PlutoUI = "~0.7.62"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.9"
manifest_format = "2.0"
project_hash = "fde3ea233e4de16d07e2e8a262d3fb4a89fea851"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "MacroTools"]
git-tree-sha1 = "3b86719127f50670efe356bc11073d84b4ed7a5d"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.42"

    [deps.Accessors.extensions]
    AxisKeysExt = "AxisKeys"
    IntervalSetsExt = "IntervalSets"
    LinearAlgebraExt = "LinearAlgebra"
    StaticArraysExt = "StaticArrays"
    StructArraysExt = "StructArrays"
    TestExt = "Test"
    UnitfulExt = "Unitful"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.AccessorsExtra]]
deps = ["Accessors", "CompositionsBase", "ConstructionBase", "DataPipes", "InverseFunctions", "LinearAlgebra", "Reexport"]
git-tree-sha1 = "57be853354c1dc6f0470e27b1c47512dd6d57835"
uuid = "33016aad-b69d-45be-9359-82a41f556fd4"
version = "0.1.95"

    [deps.AccessorsExtra.extensions]
    ColorTypesExt = "ColorTypes"
    DateFormatsExt = "DateFormats"
    DatesExt = "Dates"
    DictArraysExt = "DictArrays"
    DictionariesExt = "Dictionaries"
    DistributionsExt = "Distributions"
    DomainSetsExt = "DomainSets"
    FlexiGroupsExt = "FlexiGroups"
    FlexiMapsExt = "FlexiMaps"
    FlexiMapsStructArraysExt = ["FlexiMaps", "StructArrays"]
    SkipperExt = "Skipper"
    StaticArraysExt = "StaticArrays"
    StatisticsExt = "Statistics"
    StatsBaseExt = "StatsBase"
    StructArraysExt = "StructArrays"
    TablesExt = "Tables"
    TestExt = "Test"
    URIsExt = "URIs"
    UnitfulExt = "Unitful"

    [deps.AccessorsExtra.weakdeps]
    ColorTypes = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
    DateFormats = "44557152-fe0a-4de1-8405-416d90313ce6"
    Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
    DictArrays = "e9958f2c-b184-4647-9c5a-224a61f6a14b"
    Dictionaries = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    DomainSets = "5b8099bc-c8ec-5219-889f-1d9e522a28bf"
    FlexiGroups = "1e56b746-2900-429a-8028-5ec1f00612ec"
    FlexiMaps = "6394faf6-06db-4fa8-b750-35ccc60383f7"
    Skipper = "fc65d762-6112-4b1c-b428-ad0792653d81"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
    StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    URIs = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "e38fbc49a620f5d0b660d7f543db1009fe0f8336"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.6.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ConstructionBase]]
git-tree-sha1 = "76219f1ed5771adbb096743bff43fb5fdd4c1157"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.8"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.DataPipes]]
git-tree-sha1 = "29077a8d5c093f4e0988e92c0d76f56c4c581900"
uuid = "02685ad9-2d12-40c3-9f73-c6aeda6a7ff5"
version = "0.3.18"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
git-tree-sha1 = "a779299d77cd080bf77b97535acecd73e1c5e5cb"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.17"
weakdeps = ["Dates", "Test"]

    [deps.InverseFunctions.extensions]
    InverseFunctionsDatesExt = "Dates"
    InverseFunctionsTestExt = "Test"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MacroTools]]
git-tree-sha1 = "72aebe0b5051e5143a079a4685a46da330a40472"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.15"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "44f6c1f38f77cafef9450ff93946c53bd9ca16ff"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "d3de2694b52a01ce61a036f18ea9c0f61c4a9230"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.62"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tricks]]
git-tree-sha1 = "6cae795a5a9313bbb4f60683f7263318fc7d1505"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.10"

[[deps.URIs]]
git-tree-sha1 = "cbbebadbcc76c5ca1cc4b4f3b0614b3e603b5000"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─e003c366-a162-4575-97ab-9540c8b1b459
# ╟─5ea94011-6019-47aa-9228-1df5af684d77
# ╠═8f657eb5-ff7f-4d0c-a9ff-967f30871b6b
# ╟─67906fcb-6a41-47df-b64b-aab148d455c8
# ╠═91c72a11-a77d-456a-beeb-7e3e690828ae
# ╠═69fe774a-059d-46db-9a30-9b07679eeef5
# ╠═e1e39d1e-c273-4589-8bbc-8795190bbf4a
# ╠═118b07f9-cb3d-4ae8-86c4-9b78e7746707
# ╠═51e80a70-e931-478f-8bc4-2c45b12121af
# ╟─1ac43bdd-b707-4dbf-837f-3bda46673854
# ╠═83255b2f-18d8-4938-ab26-4a07630eddbe
# ╠═bb5ebb98-3c10-446b-b2c5-39cf271c6ba7
# ╠═dc5bca1f-8ebb-4192-bd8a-eb08dfb91ac3
# ╠═02b0cabf-0991-417b-8ec5-c8db1862fa08
# ╟─29684b6c-f786-4131-9073-daaa0a33d8e2
# ╠═23a5243e-1b56-4c44-8f0e-676781ce1b1e
# ╠═83a07b18-e186-4c0d-bc0d-216b3dda7800
# ╠═44c133ff-3c88-42d0-bf9a-a0214fb3d0c9
# ╠═b65e39ab-8a57-4498-bddf-bd64208fd2c6
# ╟─3d9451ce-81c5-4244-a524-bf233e1de521
# ╠═51e48f24-4ad9-47fc-98fe-2e65826d0cdc
# ╠═06f8917b-8542-4d37-8b71-44475a2f663a
# ╠═edd6da10-3cd1-4b70-9c4c-e15603b7f6a2
# ╠═08adc947-2c30-43cc-8138-d126c81e76a3
# ╟─c7eb40e1-e18a-4640-8d86-5f3a1ce4c23f
# ╠═eec65f2e-4a80-4c11-8ad9-a6c93a468912
# ╟─cc5c1ee4-20aa-4324-b0e9-0f8db492e72c
# ╠═b3ffef81-13e2-40ef-bb03-71c51f36f47e
# ╠═269a5a37-d4bf-4ba0-a59b-aa628e47ff3b
# ╠═c5791834-27fc-453f-9305-cb977a046d28
# ╠═2f0f1190-2377-4b30-9e71-c9d8b3b5f4ec
# ╠═10e5512f-df3b-49e9-bf03-222c05a1933a
# ╟─05a6de1b-fc64-43b5-b7e9-49789a893272
# ╠═4fc97cf0-7045-4ce1-b7ce-8faaa1fc484d
# ╠═841afae0-303a-4e1a-b1d8-b33c54787a02
# ╠═15e23d42-4215-4a9a-ab1e-7c036e77835b
# ╟─d375ae9f-2530-44bc-bd93-2c89e9c58e2a
# ╠═20350429-74ae-475b-baee-2528fd77e4c4
# ╟─bf9f7247-8aa2-4fc8-974a-65ba71021f96
# ╠═c09d4e9c-2d64-4638-9774-0697989b00b0
# ╠═ab7eb768-3dcc-491d-acd2-04ae572d7938
# ╠═102baa65-088f-4d45-882c-b293d2f0e279
# ╟─ccdc9876-95f2-4fd2-8ff0-fefe1f0f96a7
# ╠═5be7b8b2-9568-4d80-96be-fcbd0c68b16a
# ╠═a6b8c4fc-9555-4ddc-a2d8-9c2c4e65344e
# ╠═a3387faf-20df-4f3d-bf6c-f0e409ded011
# ╠═06690850-de63-4217-b619-8838f524bcc5
# ╟─2fe6a54a-e914-430b-9703-a48ad172b0bf
# ╠═c4fe8f56-2287-4fee-8c27-f23a2a3c4c40
# ╟─a0313d3a-73a5-4a0a-92e0-1f862e95cb70
# ╟─433ef25f-23fe-4646-8168-0c03a02cca69
# ╟─10fd2a3e-924b-48fc-a126-fe5f33ecedc3
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
