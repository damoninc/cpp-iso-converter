# cpp-iso-converter

`cpp-iso-converter` provides a small command-line utility for converting the GameCube-style sparse-map `.ciso` images commonly produced by Wii/GameCube backup tools into raw `.iso` files.

## Usage

```powershell
ciso2iso <input.cso> <output.iso>
```

Example:

```powershell
ciso2iso game.cso game.iso
```

## Build

The repository includes a Visual Studio solution and a simple CMake build file. No third-party compression library is required for the supported GameCube CISO variant.

Visual Studio Developer Command Prompt:

```powershell
msbuild ciso2iso.sln /p:Configuration=Release
```

CMake:

```powershell
cmake -S . -B build
cmake --build build --config Release
```

## Format support

- GameCube sparse-map `CISO` header (`CISO`)
- `0x8000` metadata region with 1-byte-per-block usage map
- `2 MiB` block images such as the tested Twilight Princess sample

## Errors

The converter rejects:

- invalid headers
- truncated block maps
- unsupported non-GameCube variants
- file-size/map mismatches
