# Published industrial instance: paper-tube case F2

Scantling includes one source-backed historical industrial demand instance in
addition to its four synthetic material demonstrations. The input is F2 from
the one-dimensional cutting-stock dataset maintained by Shunji Umetani. The
dataset page identifies F1–F6 as cases from a paper-tube factory in Japan; the
cited paper describes that factory planning problem.

- Dataset and instance source: [Umetani's 1D cutting-stock data page](https://sites.google.com/view/umepon/benchmark)
- Source archive: [`tube.zip`](https://drive.google.com/uc?export=download&id=1FEOIz0NYS4CYE9CmFEqYqMQF6h7np4m6); SHA-256 of the archive inspected for this transcription: `37ee375cffdb65593bdd9880af509dbe34c05ee6e39fcc0d64434d948171937d`.
- Paper: K. Matsumoto, S. Umetani, and H. Nagamochi, “On the one-dimensional stock cutting problem in the paper tube industry,” *Journal of Scheduling*, 14, 281–290 (2011), [doi:10.1007/s10951-010-0164-2](https://doi.org/10.1007/s10951-010-0164-2).
- Selected record: `f2` in the dataset's `tube.zip` archive.

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

## Verification boundary

The test confirms the transcribed inputs and model accounting. It does not
compare Scantling's heuristic against the factory's deployed plan, the paper's
multi-constraint algorithm, or an optimal solution. The F2 record does not
contain enough information to calculate purchase costs or validate kerf and
remnant assumptions.
