# CISO2ISO Design

## Goal

Create a small C++ command-line tool that converts standard PSP-style `.cso` images into `.iso` files.

## Interface

The tool accepts two arguments:

```text
ciso2iso <input.cso> <output.iso>
```

It exits with code `0` on success and a non-zero code with a clear error message on failure.

## Approach

The converter reads the CISO header, validates the format, loads the block index table, and writes the decoded blocks to the output ISO in block order.

Compressed blocks use raw DEFLATE decompression through the Windows Compression API. Blocks marked as plain are copied directly into the ISO stream.

## Error handling

The converter rejects malformed headers, truncated index tables, invalid block ranges, and decompression failures. It also validates the final block size so the output length matches the declared ISO size.

## Testing

The repository includes a minimal test fixture generator for malformed input and a build target that can be compiled locally. Full end-to-end verification with a real `.cso` sample remains an external follow-up item.
