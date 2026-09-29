// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0
//
// Small transcription from a published Japanese chemical-fiber application
// dataset. Third-party input data is not relicensed by this source header.
// See docs/real-data-case.md for provenance and the relaxation boundary.

///|
fn chemical_fiber_06_inputs(
  stock_length_mm : Double,
) -> (@core.StockMaterial, Array[@core.DemandItem], @core.OptimizationConfig) {
  let stock = @core.StockMaterial::new(
    "CHEMICAL-FIBER-06", "Chemical-fiber stock roll (published instance 06)", stock_length_mm,
    0.0, 0.0,
  )
  let demands = [
    @core.DemandItem::new("CF06-01", 520.0, 91, "source row 1"),
    @core.DemandItem::new("CF06-02", 1000.0, 11, "source row 2"),
    @core.DemandItem::new("CF06-03", 1066.0, 18, "source row 3"),
    @core.DemandItem::new("CF06-04", 1120.0, 9, "source row 4"),
    @core.DemandItem::new("CF06-05", 1150.0, 64, "source row 5"),
    @core.DemandItem::new("CF06-06", 1250.0, 5, "source row 6"),
  ]
  // The source publishes 5,180 mm and 9,080 mm stock variants. Kerf,
  // mass, price, remnant threshold, and pattern-change costs are not
  // provided. The threshold below is a neutral placeholder; no remnant
  // valuation is run, and it does not affect stock-roll count.
  let config = @core.OptimizationConfig::new(0.0, stock_length_mm)
  (stock, demands, config)
}

///|
pub fn run_chemical_fiber_06() -> Unit {
  println(
    "\nHistorical chemical-fiber application instance 06 (relaxed replay)",
  )
  println("  Source demand: 6 types; 198 pieces; 167438 mm total length")
  println("  kerf and material cost: not supplied; cost not calculated")
  for stock_length_mm in [9080.0, 5180.0] {
    let (stock, demands, config) = chemical_fiber_06_inputs(stock_length_mm)
    let summary = match
      @optimizer.try_optimize_cutting_stock(stock, demands, config) {
      Ok(value) => value
      Err(_) => abort("Published chemical-fiber instance validation failed")
    }
    let unused_length = summary.total_stock_length_mm -
      summary.total_demanded_length_mm -
      summary.total_kerf_loss_mm
    println(
      "  stock " +
      stock_length_mm.to_string() +
      " mm: " +
      summary.total_stocks_used.to_string() +
      " rolls; unused " +
      unused_length.to_string() +
      " mm",
    )
    if stock_length_mm == 9080.0 {
      println("    length-only lower bound: 19 rolls")
    } else {
      println("    length-only lower bound: 33 rolls")
    }
  }
  println(
    "  Aggregate-demand relaxation only; published pattern-change objective and other constraints are not reproduced.",
  )
}
