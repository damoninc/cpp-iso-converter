# Test Notes

`invalid_magic.cso` is a deliberately malformed fixture used to verify that the converter rejects files without a valid `CISO` header.

Smoke test entry points:
- Windows: `tests/smoke.ps1`
- Linux/macOS (bash): `tests/smoke.sh`
