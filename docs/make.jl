using EpiEconShocks
using Documenter
using DocumenterCitations

DocMeta.setdocmeta!(EpiEconShocks, :DocTestSetup, :(using EpiEconShocks); recursive = true)

bib = CitationBibliography(
    joinpath(@__DIR__, "src", "refs.bib");
    style = :numeric
)

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
        "Working with epi outputs" => [
            "Estimating labour and consumption over an epidemic" => "estim_lab_consump.md",
            "Estimating costs of long-term disability" => "disability_costs.md"
        ],
        "Working with GTAP" => [
            "Setting up a GTAP model" => "setup.md",
            "Using epi model outputs with GTAP" => "daedalus.md"
        ],
        "Index" => "pkg_index.md",
        "Function Reference" => "reference.md"
    ],
    plugins = [bib]
)

deploydocs(;
    repo = "github.com/jameel-institute/EpiEconShocks.jl",
    devbranch = "main",
    versions = "v^"
)
