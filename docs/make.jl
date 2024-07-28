using BioS_ProjsWFs
using Documenter

DocMeta.setdocmeta!(BioS_ProjsWFs, :DocTestSetup, :(using BioS_ProjsWFs); recursive=true)

makedocs(;
    modules=[BioS_ProjsWFs],
    authors="Cristina Moraru",
    sitename="BioS_ProjsWFs.jl",
    format=Documenter.HTML(;
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
