# setup-jl
An opinionated way to create Julia packages with Semantic Release

Much Credit to Jaan Tollander de Balsch.
I modified much of this from [his work](https://github.com/jaantollander/SemanticReleaseExample.jl).

This uses julia 1.9.2

## Usage

1. Clone this repository.
2. Instantiate the project (download the dependencies) by running `julia --project -e 'import Pkg; Pkg.instantiate()'`
3. Modify *config.toml* to match your preferences.
4. Create an empty repository with the correct path on GitHub.
5. Run the script with `julia --project -e 'include("setup.jl"); createpackage("config.toml")'`. This will populate that empty repo automatically.
6. Follow the instructions in the created README to finish setting the repo up.

That's it!

Make sure to familiarise yourself with [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) as these are how you'll trigger the release pipeline.
