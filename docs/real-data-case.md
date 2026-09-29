# Published industrial demand replays

Scantling includes source-backed historical demand examples from two Japanese
manufacturing application datasets, alongside four synthetic material/cost
demonstrations. Both executable examples below are explicitly **relaxed
aggregate-demand replays**, not reproductions of the source papers' complete
optimization problems or factory schedules.

- Dataset index: [Shunji Umetani's 1D cutting-stock data page](https://sites.google.com/view/umepon/benchmark).

## Paper-tube factory F2

- Source archive: [`tube.zip`](https://drive.google.com/uc?export=download&id=1FEOIz0NYS4CYE9CmFEqYqMQF6h7np4m6); SHA-256 of the inspected archive: `37ee375cffdb65593bdd9880af509dbe34c05ee6e39fcc0d64434d948171937d`.
- Paper: K. Matsumoto, S. Umetani, and H. Nagamochi, “On the one-dimensional stock cutting problem in the paper tube industry,” *Journal of Scheduling*, 14, 281–290 (2011), [doi:10.1007/s10951-010-0164-2](https://doi.org/10.1007/s10951-010-0164-2).
- Selected record: `f2` in `tube.zip`. The source lists six paper-tube application instances; F2 has one stock length and maps most directly to the current single-stock API.

## Recorded inputs

The F2 file records one stock-roll type of 1,800 mm and 15 item types. The
source rows below are transcribed as `(length_mm, demand, lot_size)`. The
executable uses only the first two fields; `lot_size` is shown for provenance
but is not modeled.

| Length (mm) | Demand | Lot size |
| ---: | ---: | ---: |
| 411 | 10 | 10 |
| 360 | 100 | 10 |
| 310 | 40 | 10 |
| 215 | 100 | 10 |
| 206 | 190 | 10 |
| 200 | 20 | 10 |
| 184 | 30 | 10 |
| 180 | 110 | 10 |
| 151 | 100 | 10 |
| 150 | 130 | 10 |
| 135 | 180 | 10 |
| 120 | 30 | 10 |
| 100 | 100 | 10 |
| 90 | 340 | 10 |
| 88 | 20 | 10 |

The listed demand totals 1,500 pieces and 247,330 mm. The executable
transcription is in `examples/scenarios/real_paper_tube_f2.mbt`; its test checks
the source dimensions, counts, and length conservation. With this repository's
current FFD/BFD candidate selection and zero-kerf replay, Scantling uses 139
rolls and leaves 2,870 mm unallocated. The simple length lower bound is 138
rolls; the heuristic result is not asserted to be optimal.

## What the replay means—and does not mean

`moon run examples/quickstart` runs F2 through Scantling's checked one-stock-size
optimizer. The source does not provide blade kerf, material mass per metre, or
prices, so the replay uses zero kerf and calculates no cost. It also ignores the
source's lot/setup and open-stack constraints and optimizes only the number of
1,800 mm rolls for aggregate demand. Its output is therefore a reproducible
**relaxation of a published real-application instance**, not a reproduction of
the factory's full production plan or a claim of factory performance. The four
cross-material cost examples remain synthetic.

The source page makes the archive publicly accessible but does not state a data
license. This repository attributes the source and includes only the small F2
input transcription needed to reproduce the demonstration; it does not claim
that the third-party data is relicensed under Apache-2.0.

## Chemical-fiber company instance 06

- Source archive: [`fiber.zip`](https://drive.google.com/uc?export=download&id=1qW7RB46CFtq09_1kofyoSfbpHhALh5F9); SHA-256 of the inspected archive: `b033fdf9977bc886c067b07584b36780e68fdac7ffe1f15682c682fb44267b98`.
- Selected records: `fiber/fiber06_9080.txt` and `fiber/fiber06_5180.txt`; both contain the same six product demands with alternative stock lengths of 9,080 mm and 5,180 mm.
- Paper: S. Umetani, M. Yagiura, and T. Ibaraki, “One dimensional cutting stock problem to minimize the number of different patterns,” *European Journal of Operational Research*, 146 (2003), 388–402, [doi:10.1016/S0377-2217(02)00239-4](https://doi.org/10.1016/S0377-2217(02)00239-4).

The six source rows are transcribed as `(length_mm, demand)`:

| Length (mm) | Demand |
| ---: | ---: |
| 520 | 91 |
| 1,000 | 11 |
| 1,066 | 18 |
| 1,120 | 9 |
| 1,150 | 64 |
| 1,250 | 5 |

These sum to 198 pieces and 167,438 mm. Scantling uses 19 rolls for the
9,080 mm variant (length-only lower bound 19; 5,082 mm unused) and 34 rolls
for the 5,180 mm variant (lower bound 33; 8,682 mm unused). Tests check the
transcribed totals, both source stock lengths, solver outputs, and length
conservation. The source paper's objective is to minimize the number of
different cutting patterns and it permits its own surplus/shortage treatment,
whereas this replay minimizes stock-roll count while exactly meeting aggregate
demand. The published pattern objective, demand-deviation treatment, and other
application constraints are not modeled. This is a cross-industry input
exercise, not a direct reproduction or comparative-performance claim.

## Shared data and verification limits

Neither source provides the kerf, material mass per metre, or purchase prices
needed for Scantling's cost model. The replays use zero kerf and calculate no
cost. The chemical-fiber remnant threshold is a structural placeholder and is
not used to value stock. The paper-tube F2 source's lot/setup and open-stack
constraints are not modeled. Neither replay compares against a factory's
deployed plan, proves optimality, or establishes field performance. The four
cross-material cost examples remain synthetic.

The source page makes both archives publicly accessible but does not state a
data license. This repository provides attribution and only small input
transcriptions needed to reproduce these examples; it does not claim that
third-party data is relicensed under Apache-2.0. Source archive checksums are
recorded above to make the inspected files identifiable.
