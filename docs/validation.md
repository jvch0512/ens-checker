# Validation on real data

Counts below were produced by running the tool on public data, not on the synthetic samples in `examples/`.

## Validation
Measure identifiers were checked against the official text of Real Decreto 311/2022, Annex II (BOE-A-2022-7191). Several identifiers were wrong in the first version (for example `mp.info.6` and `op.exp.8` and their reinforcements) and were corrected. Messages now say "the ENS reference value is" because the level of a measure depends on the system category (BÁSICA, MEDIA, ALTA).

## Limits
The tool compares a declared state to reference values. It is not an ENS audit and does not replace the Annex III verification.
