# TRU release comment cleanup 01

This is a source-only cleanup candidate based on the uploaded TRU-main(2).zip.
It is not a production-readiness certification, security audit, or runtime upgrade.

## What changes

- 575 line comments in 55 first-party C++ source/header files are shortened or rewritten.
- Removes conversational insertion instructions, promotional adjectives, and leading historical patch labels where the technical explanation remains intact.
- Preserves all non-comment text, raw string contents (including embedded GPU kernels), comment boundaries, and physical source line counts.
- Preserves third-party library files, generated protobuf files, licenses, block comments, and protected marker comments.
- Updates the 162-entry source manifest and the active source release identity. All 48 ledger file pins are rechecked.
- Copies a reviewed allowlist of 267 files into a new source folder. It does not copy arbitrary files from the operator's machine.

The website, legacy magic-miner copies, bundled Python virtual environment, two source backup files, and installer lock files are excluded from this Core-source candidate. They are not deleted from the original checkout. The website remains a separate release task. Current source, tests, Agent, Market, configuration templates, and documentation are retained.

## Source and runtime separation

The patch never modifies its input checkout, starts or stops services, calls RPC, broadcasts transactions, or accesses wallet/chain databases. It does not copy Git history, compiled binaries, private configuration, or a machine build receipt.

The candidate has a new source identity. Build it from an exact reviewed commit to obtain a truthful machine receipt. Do not copy the previous ACTIVE.json receipt into the candidate or overwrite the existing live binaries. Check_TRU_Swap.sh is a runtime checker; a source-only candidate is not expected to pass it before a build and setup.

## Review before publication

This cleanup does not resolve underlying implementation limitations. In particular:

- src/block.cpp contains a zero-knowledge verification placeholder; its warning is retained and clarified.
- src/utxo.cpp contains a cryptographic-verification stub; its warning is retained and clarified. Reachability and production impact need a separate review.
- src/oobalooga_ai_.h contains a literal local-provider API-key default. Its value is not changed by this comments-only patch. Assess whether this header is used and replace live credentials with private configuration before publication.
- A top-level license, dependency notice review, security-reporting policy, documented test runner/CI, reproducible dependency versions, and clean-machine runtime validation remain release tasks.
- Existing roadmap prose can contain stale or conflicting status claims. This patch does not certify or rewrite those claims.

Do not hide these limitations by removing their comments. Cleanup improves readability; functional repairs require their own review and tests.

## Validation supplied

The package includes offline tests for string/raw-string preservation, line splicing, source-line preservation, exact hashes, new release metadata, unknown input rejection, symlink rejection, existing output protection, concurrent changes, and write failure cleanup. The production source diff is checked by the same comment-boundary guard.

No full C++ build, live node test, two-node convergence proof, or funded swap is performed by this package. Compilation and runtime verification must be completed on the candidate before shipping binaries.

REVIEW.diff contains the complete C++ comment diff. comment_changes.json lists every old/new comment and original source line. Source paths and line counts are retained to keep that review usable.
