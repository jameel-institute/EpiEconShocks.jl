using EpiEconShocks
using Documenter

DocMeta.setdocmeta!(EpiEconShocks, :DocTestSetup, :(using EpiEconShocks); recursive = true)

makedocs(;
    modules = [EpiEconShocks],
    authors = "Imperial College London",
    sitename = "EpiEconShocks.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://jameel-institute.github.io/EpiEconShocks.jl",
        edit_link = "main",
        assets = String[]
    ),
    checkdocs = :exports,
    pages = [
        "Home" => "index.md",
        "Setting up GTAP" => "setup.md",
        "Realistic use case" => "daedalus.md"
    ]
)

deploydocs(;
    repo = "github.com/jameel-institute/EpiEconShocks.jl",
    devbranch = "main"
)
