# CISO2ISO Design

## Goal

Create a small C++ command-line tool that converts the GameCube-style sparse-map `.ciso` format used by Wii/GameCube backup tools into `.iso` files.

## Interface

The tool accepts two arguments:

```text
ciso2iso <input.ciso> <output.iso>
```

It exits with code `0` on success and a non-zero code with a clear error message on failure.

## Approach

The converter reads the GameCube CISO header, validates the `CISO` magic and block size, loads the 1-byte-per-block usage map from the `0x8000`-byte metadata region, and reconstructs the ISO by writing stored blocks and zero-filling holes.

The implementation is GameCube-only. It confirms the first stored block looks like a GameCube disc image by checking the reconstructed disc header and the GameCube disc magic.

## Error handling

The converter rejects malformed headers, truncated block maps, invalid block-map entries, undersized files, and unsupported non-GameCube variants. It preserves the raw disc size of a full GameCube ISO in the output.

## Testing

The repository includes a smoke test that rebuilds the Release executable, checks CLI error handling, and verifies malformed-header rejection. End-to-end conversion has also been validated against a real GameCube `.ciso` sample.
