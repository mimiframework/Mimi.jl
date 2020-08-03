using Documenter, Mimi

makedocs(
	doctest = false,
    modules = [Mimi],
	sitename = "Mimi.jl",
	pages = [
		"Home" => "index.md",
		"Tutorials" => Any[
			"Tutorials Intro" => "tutorials/tutorial_main.md",
			"1 Install Mimi" => "tutorials/tutorial_1.md",
			"2 Run an Existing Model" => "tutorials/tutorial_2.md",
			"3 Modify an Existing Model" => "tutorials/tutorial_3.md",
			"4 Create a Model" => "tutorials/tutorial_4.md",
			"5 Sensitivity Analysis" => "tutorials/tutorial_5.md"
		],
		"How-to Guides" => Any[
			"How-to Guides Intro" => "howto/howto_main.md",
			"1 Construct + Run a Model" => "howto/howto_1.md",
			"2 Explore Results" => "howto/howto_2.md",
			"3 Sensitivity Analysis" => "howto/howto_3.md",
			"4 Timesteps, Params, and Vars" => "howto/howto_4.md",
			"5 Port to v0.5.0" => "howto/howto_5.md",
			"6 Port to v1.0.0" => "howto/howto_6.md"
		],
		"Advanced How-to Guides" => Any[
			"Advanced How-to Guides Intro" => "howto_advanced/howto_adv_main.md",
			"Build and Init Functions" => "howto_advanced/howto_adv_buildinit.md",
			"Using Datum References" => "howto_advanced/howto_adv_datumrefs.md"
		],
		"Reference Guides" => Any[
			"Reference Guides Intro" => "ref/ref_main.md",
			"Mimi API" => "ref/ref_API.md",
			"Structures" => "ref/ref_structures.md", 
			"Structures: Definitions" => "ref/ref_structures_definitions.md", 
			"Structures: Instances" => "ref/ref_structures_instances.md"
		],
		"FAQ" => "faq.md",
	],
	format = Documenter.HTML(prettyurls = get(ENV, "JULIA_NO_LOCAL_PRETTY_URLS", nothing) === nothing)
)

deploydocs(
    repo = "github.com/mimiframework/Mimi.jl.git",
)
