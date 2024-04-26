using Documenter, TestReports

makedocs(
    modules = [TestReports],
    authors =  "Lyndon White, Malcolm Miller and contributors",
    sitename="TestReports.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://juliatesting.github.io/TestReports.jl/stable",
    ),
    pages=[
        "Home" => "index.md",
        "Manual" => "manual.md",
        "Library" => "library.md",
        "Contributing" => "contributing.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaTesting/TestReports.jl",
    push_preview=true,
)