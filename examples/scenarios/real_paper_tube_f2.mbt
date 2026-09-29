// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0
//
// One historical real-application instance transcribed from Umetani et al.'s
// public paper-tube cutting-stock dataset. The data values are third-party
// source data and are not relicensed by this source-file header. See
// docs/real-data-case.md.

///|
fn paper_tube_f2_inputs() -> (
  @core.StockMaterial,
  Array[@core.DemandItem],
  @core.OptimizationConfig,
) {
  let stock = @core.StockMaterial::new(
    "PAPER-TUBE-F2", "Paper-tube stock roll (published F2 case)", 1800.0, 0.0, // Not supplied by the source; this replay does not calculate cost.
     0.0, // Not supplied by the source; this replay does not calculate cost.
  )
  let demands = [
    // The source's lot_size column is intentionally not represented by DemandItem.
    @core.DemandItem::new("F2-01", 411.0, 10, "source row 1"),
    @core.DemandItem::new("F2-02", 360.0, 100, "source row 2"),
    @core.DemandItem::new("F2-03", 310.0, 40, "source row 3"),
    @core.DemandItem::new("F2-04", 215.0, 100, "source row 4"),
    @core.DemandItem::new("F2-05", 206.0, 190, "source row 5"),
    @core.DemandItem::new("F2-06", 200.0, 20, "source row 6"),
    @core.DemandItem::new("F2-07", 184.0, 30, "source row 7"),
    @core.DemandItem::new("F2-08", 180.0, 110, "source row 8"),
    @core.DemandItem::new("F2-09", 151.0, 100, "source row 9"),
    @core.DemandItem::new("F2-10", 150.0, 130, "source row 10"),
    @core.DemandItem::new("F2-11", 135.0, 180, "source row 11"),
    @core.DemandItem::new("F2-12", 120.0, 30, "source row 12"),
    @core.DemandItem::new("F2-13", 100.0, 100, "source row 13"),
    @core.DemandItem::new("F2-14", 90.0, 340, "source row 14"),
    @core.DemandItem::new("F2-15", 88.0, 20, "source row 15"),
  ]
  // The source provides no kerf or remnant-reuse threshold. Zero kerf keeps
  // the replay on the recorded length-only instance; the threshold does not
  // affect the number-of-rolls objective.
  let config = @core.OptimizationConfig::new(0.0, 1800.0)
  (stock, demands, config)
}

///|
pub fn run_paper_tube_f2() -> Unit {
  let (stock, demands, config) = paper_tube_f2_inputs()
  let summary = match
    @optimizer.try_optimize_cutting_stock(stock, demands, config) {
    Ok(value) => value
    Err(_) => abort("Published paper-tube F2 replay input validation failed")
  }
  let remnant_length = summary.total_stock_length_mm -
    summary.total_demanded_length_mm -
    summary.total_kerf_loss_mm
  println("\nHistorical paper-tube factory instance F2 (relaxed replay)")
  println("  Source stock length: 1800 mm; demand types: 15; pieces: 1500")
  println("  Source demand length: 247330 mm")
  println("  kerf and material cost: not supplied; cost not calculated")
  println(
    "  Scantling heuristic stock rolls: " +
    summary.total_stocks_used.to_string(),
  )
  println(
    "  Total unused length in this replay: " +
    remnant_length.to_string() +
    " mm",
  )
  println("  Source setup, lot, and open-stack constraints are not modeled.")
}
