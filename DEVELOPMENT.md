# Development

##### Prerequisites

* [jq](https://stedolan.github.io/jq/)
    * macOS: `brew install jq`
    * Windows: `choco install jq`
    * Ubuntu: `sudo apt install jq`
* Make
    * macOS: `xcode-select --install`
    * Windows: `choco install make`
    * Ubuntu: `sudo apt install make`
* Python 3 (optional, for alternative server)
    * macOS: `brew install python3`
    * Windows: `choco install python3`
    * Ubuntu: `sudo apt install python3`

#### Serve

Serve docs at http://localhost:1313

```bash
make serve
```

#### Serve with Python

Alternative way to serve built documentation using Python 3:

```bash
make serve-python
```

Or directly:

```bash
python3 tools/server.py 1313
```

#### Build

```bash
make build
```

#### Clean

```bash
make clean
```