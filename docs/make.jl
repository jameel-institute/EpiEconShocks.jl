using EpiEconShocks
using Documenter

DocMeta.setdocmeta!(EpiEconShocks, :DocTestSetup, :(using EpiEconShocks); recursive=true)

makedocs(;
    modules=[EpiEconShocks],
    authors="Imperial College London",
    sitename="EpiEconShocks.jl",
    format=Documenter.HTML(;
        canonical="https://jameel-institute.github.io/EpiEconShocks.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jameel-institute/EpiEconShocks.jl",
    devbranch="main",
)
