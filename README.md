# Blog

## Installation

1. Install hugo: `go install github.com/gohugoio/hugo@latest`
2. We installed the blowfish them through submodule: [link](https://blowfish.page/docs/installation/#install-using-git)
    - To update the theme verion, do: `git submodule update --init --recursive`

## Usage

> Refer to `Makefile`

- Serve locally in dev mode: `make dev`
- Deploy locally: `make deploy`
- Create new content:
    - English: `make new-en`
    - Traditional Chinese: `make new-zh`
    - Both: `make new`
