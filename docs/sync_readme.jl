
using EpiEconShocks # import for package version

"""
    generate_version_badge(version::String)

Generate a shields.io version badge markdown string.
"""
function generate_version_badge(version::VersionNumber)
    badge_url = "https://img.shields.io/badge/version-$(version)-aquamarine.svg"
    docs_url = "https://jameel-institute.github.io/EpiEconShocks.jl/dev/"
    return "[![Version]($badge_url)]($docs_url)"
end

"""
    sync_readme()

Render docs/src/index.md as plain markdown and copy to README.md,
stripping out Documenter.jl-specific syntax. Inserts package version badge.
"""
function sync_readme()
    src_file = joinpath(@__DIR__, "src", "index.md")
    dest_file = joinpath(dirname(@__DIR__), "README.md")

    # Get version and generate badge
    version = pkgversion(EpiEconShocks)
    badge = generate_version_badge(version)

    # Read source file - this is docs/src/index.md
    content = read(src_file, String)

    # Insert version badge after the first badge line
    content = replace(content,
        r"(\n\[!\[Version\]\(.*?\)\]\(.*?\)\n)"s => "\n$badge\n")

    # Update docs/src/index with correct version
    write(src_file, content)

    # Remove @meta blocks
    content = replace(content, r"```@meta\n.*?\n```\n*"s => "")

    # Convert @example blocks to regular code blocks
    content = replace(content, r"```@example\s+\w+\n"s => "```julia\n")

    # Insert version badge after the first badge line
    content = replace(content,
        r"(\n\[!\[Version:.*?\]\(.*?\)\]\(.*?\)\n)"s => "\n$badge\n")

    # Write to temporary file
    write(dest_file, content)

    println("✓ Readme and index updated with version $version")
end

sync_readme()
