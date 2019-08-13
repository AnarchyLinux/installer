# Anarchy Linux website

## Building prerequisites

* `hugo` (extended) - either build it from [source](https://github.com/gohugoio/hugo) or download it from their [releases page](https://github.com/gohugoio/hugo/releases)
* nodejs (`npm`)
* `autoprefixer` (npm install autoprefixer)
* `postcss-cli` (npm install postcss-cli)


## Update submodules

`git submodule update --recursive --remote`


## Build the website (and publish it)

* Run the `deploy.sh` script to build and push the website to the `gh-pages` branch of the **origin** remote.