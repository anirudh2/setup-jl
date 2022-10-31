import Git as G

using PkgTemplates
using PkgTemplates: PkgTemplates

using TOML

struct SemanticReleaseBadge <: PkgTemplates.BadgePlugin end

"""
Badge for semantic release
"""
function PkgTemplates.badges(::SemanticReleaseBadge)
    return PkgTemplates.Badge(
        "semantic-release",
        "https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg",
        "https://github.com/semantic-release/semantic-release",
    )
end

function PkgTemplates.badges(::Documenter{<:PkgTemplates.GitHubPagesStyle})
    return [
        PkgTemplates.Badge(
            "Latest",
            "https://img.shields.io/badge/docs-latest-purple.svg",
            "https://{{{USER}}}.github.io/{{{PKG}}}.jl/latest/",
        ),
    ]
end

function PkgTemplates.badges(::Coveralls)
    return PkgTemplates.Badge(
        "Coverage Status",
        "https://img.shields.io/coveralls/github/{{{USER}}}/{{{PKG}}}.jl/badge.svg?branch={{{BRANCH}}}",
        "https://coveralls.io/github/{{{USER}}}/{{{PKG}}}.jl?branch={{{BRANCH}}}",
    )
end

"""
    createpackage(path::AbstractString)

Create a package with semantic release using the configuration in the TOML file at `path`

Run using `julia -e 'include("setup.jl"); createpackage(path)'`
"""
function createpackage(path::AbstractString)
    config = TOML.parsefile(path)
    return createpackage(;
        name=config["name"],
        user=config["user"],
        authors=config["authors"],
        julia=VersionNumber(config["julia"]...),
        dir=config["dir"],
        license=config["license"],
    )
end

"""
    createpackage(;name="MyProject.jl", user="anirudh2", authors="Anirudh A. Patel", julia=v"1.8", dir="~/projects/", licensetype="MIT")

Create a package with semantic release.

Run using `julia -e 'include("setup.jl"); createpackage(;kwargs)'`

- `user` is the part of the GitHub URL that comes after github.com. E.g., github.com/anirudh2 => user="anirudh2"
- `license` can be "MIT", "ASL" (Apache 2), "GPL", etc. A full list is available on [github](https://github.com/JuliaCI/PkgTemplates.jl/tree/master/templates/licenses)
"""
function createpackage(; name, user, authors, julia, dir, license)
    @info "Creating Package"
    t = PkgTemplates.Template(;
        user=user,
        authors=authors,
        julia=julia,
        dir="~/projects/",
        plugins=[
            Git(; gpgsign=true, ssh=true),
            GitHubActions(; extra_versions=String[], coverage=true),
            Coveralls(),
            Documenter{PkgTemplates.GitHubActions}(),
            BlueStyleBadge(),
            Citation(),
            License(; name=license),
            Tests(; project=true),
            SrcDir(),
            ProjectFile(),
            SemanticReleaseBadge(),
            CompatHelper(),
            !TagBot,
        ],
    )
    t(name)

    @info "Copying Relevant Files To Package Repo"
    namesplit = first(splitext(name))
    fulldir = realpath(expanduser(dir))
    path = joinpath(fulldir, namesplit)
    cp("Release.yml", joinpath(path, ".github", "workflows", "Release.yml"))
    cp("dco_check.yml", joinpath(path, ".github", "workflows", "dco_check.yml"))
    cp(".releaserc", joinpath(path, ".releaserc"))
    cp("CHANGELOG.md", joinpath(path, "CHANGELOG.md"))
    cp(".JuliaFormatter.toml", joinpath(path, ".JuliaFormatter.toml"))

    @info "Correcting initial version"
    tomlpath = joinpath(path, "Project.toml")
    modfile(tomlpath, x -> x == "version = \"0.1.0\"\n", "version = \"0.0.0\"\n")

    @info "Setting correct devurl for Documentation"
    makedocpath = joinpath(path, "docs", "make.jl")
    # \t is 8 spaces, so just use 4 spaces manually
    modfile(
        makedocpath,
        x -> contains(x, "devbranch"),
        "    devbranch=\"main\",\n    devurl=\"latest\",\n",
    )

    @info "Setting git repo for semantic release"
    releasercpath = joinpath(path, ".releaserc")
    modfile(
        releasercpath,
        x -> contains(x, "repositoryUrl"),
        "  \"repositoryUrl\": \"git@github.com:$user/$name.git\"",
    )

    @info "Setting up coveralls"
    ciymlpath = joinpath(path, ".github", "workflows", "CI.yml")
    modfile(
        ciymlpath,
        x -> contains(x, "julia-runtest"),
        "      - uses: julia-actions/julia-runtest@v1\n      - uses: julia-actions/julia-processcoverage@v1\n",
    )
    modfile(
        ciymlpath,
        x -> contains(x, "COVERALLS_TOKEN"),
        "          COVERALLS_TOKEN: \${{ secrets.GITHUB_TOKEN }}\n",
    )

    @info "Appending post-setup instructions to README"
    open(joinpath(path, "README.md"), "a") do io
        lines = [
            "\n## TODO\n",
            "\n I generally recommend doing step 1 running this script, but it's not a big deal if you do it after.\n",
            "\n1. Go to [Coveralls](https://coveralls.io/) and activate this repo.",
            "\n2. Once CI finishes running for the first time, go to Settings, Pages, and select the branch `gh-pages`",
            "\n3. Once you've done these things, delete this TODO section and commit the change with the message `chore: finished repo setup`",
        ]
        for line in lines
            write(io, line)
        end
    end

    @info "Creating initial commit and tag"
    @warn "This will fail if you have not created the upstream repo on GitHub at the correct URL."
    @warn "You must also have gpg commit signing set up."
    cd(path)
    run(`$(G.git()) add .`)
    run(`$(G.git()) commit -m "chore: Set up project"`)
    run(`$(G.git()) tag v0.0.0 -m "Set up project"`)
    return run(`$(G.git()) push --set-upstream origin main v0.0.0`)
end

"""
Modify the file at `path` at lines that match `predicate`, replacing the lines with
`replacement`
"""
function modfile(path::String, predicate::F, replacement::String) where {F<:Function}
    # https://stackoverflow.com/questions/58013970/how-to-edit-a-line-of-a-file-in-julia
    (tmppath, tmpio) = mktemp()
    open(path) do io
        for line in eachline(io; keep=true)
            if predicate(line)
                line = replacement
            end
            write(tmpio, line)
        end
    end
    close(tmpio)
    mv(tmppath, path; force=true)
    return nothing
end
