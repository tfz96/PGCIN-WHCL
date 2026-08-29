# PGCIN-WHCL

Reproducibility package for the manuscript **PGCIN-WHCL: A Planetary-Gear-Constrained Finite-Depth Joint Reversible Image Encryption Scheme Without Cross-Macroblock Payload Feedback**.

The repository contains the production MATLAB implementation, manuscript experiment scripts, derived result tables used by the paper, figure-generation inputs, and reproduction instructions.

## Requirements

- MATLAB R2024a or a compatible recent MATLAB release.
- The original Kodak-24 image set for experiments that use natural images. The image files are not redistributed here; see `matlab/data/kodak/README.md` and verify the downloaded files with `kodak24_checksums.csv`.

## Quick start

From the repository root in MATLAB:

```matlab
addpath('PGCIN_WHCL_CLEAN')
run_pgcinwhcl_clean_gate
```

The gate checks exact round trips over representative tile sizes and the WHCL reconstruction constraints.

For direct image use:

```matlab
addpath('PGCIN_WHCL_CLEAN')
cfg = pgcinwhcl.defaultConfig();
cfg = pgcinwhcl.withNonce(cfg, uint8(0:15));
[cipher, meta] = pgcinwhcl.encryptImage(image, cfg);
plain = pgcinwhcl.decryptImage(cipher, cfg, meta);
```

To run the manuscript experiment suite after placing Kodak-24 under `matlab/data/kodak/`:

```matlab
addpath('PGCIN_WHCL_CLEAN')
addpath(fullfile('PGCIN_WHCL_CLEAN', 'experiments'))
run_manuscript_experiment_suite('full', 'local_reproduction')
```

The suite writes generated runs under `PGCIN_WHCL_CLEAN/experiments/runs/`; these generated directories are intentionally ignored by Git. The checked-in `experiments/results/` contains the manuscript-aligned derived results used for the submitted tables and figure inputs.

## Rebuilding figures

```matlab
addpath('PGCIN_WHCL_CLEAN')
addpath(fullfile('PGCIN_WHCL_CLEAN', 'experiments'))
setenv('PGCIN_WHCL_RESULT_ROOT', fullfile(pwd, 'PGCIN_WHCL_CLEAN', 'experiments', 'results'))
setenv('PGCIN_WHCL_FIGURE_OUTPUT_ROOT', fullfile(pwd, 'figures_generated'))
generate_manuscript_figures([3 5 6 7 8 9 10 11 12], false)
```

## Manuscript and figures

The submission LaTeX sources are kept in the separate manuscript directory and
are not part of this code/data release. The formal manuscript PDF figures are
also kept outside this code/data release; the repository retains the figure
generation scripts and the result inputs needed to reproduce them locally.

The paper reports derived measurements rather than redistributing the Kodak-24 source images. This release contains no private keys, credentials, planning notes, or local build logs.

## License and third-party data

The MATLAB code and derived result files are released under the MIT License; see
`LICENSE`. Kodak-24 remains subject to its original source terms and is not
redistributed or relicensed by this repository.

If you use this package, please cite the associated manuscript. A machine-readable
citation record is provided in `CITATION.cff`.
