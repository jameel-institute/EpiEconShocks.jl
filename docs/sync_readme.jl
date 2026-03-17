"""
    sync_readme()

Render docs/src/index.md as plain markdown and copy to README.md,
stripping out Documenter.jl-specific syntax.
"""
function sync_readme()
    src_file = joinpath(@__DIR__, "src", "index.md")
    tmp_file = joinpath(@__DIR__, ".readme_tmp.md")
    dest_file = joinpath(dirname(@__DIR__), "README.md")

    # Read source file
    content = read(src_file, String)

    # Remove @meta blocks
    content = replace(content, r"```@meta\n.*?\n```\n*"s => "")

    # Convert @example blocks to regular code blocks
    content = replace(content, r"```@example\s+\w+\n"s => "```julia\n")

    # Write to temporary file
    write(tmp_file, content)

    # Copy to README.md
    run(`cp $tmp_file $dest_file`)
    run(`rm $tmp_file`)

    println("✓ README.md updated from docs/src/index.md")
end

sync_readme()
