// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0
//
// A compact, public-API-first example for reviewers and new users.

///|
fn print_metric(label : String, value : String) -> Unit {
  println("  " + label + ": " + value)
}

///|
fn main {
  println("Scantling quickstart demo")
  println("A small end-to-end run: validate -> optimize -> price")
  println(
    "Note: the optimizer is a deterministic FFD/BFD heuristic, not a global optimum proof.",
  )

  let stock = @core.StockMaterial::new(
    "DEMO-D25", "演示用螺纹钢 Φ25", 9000.0, 3.85, 3850.0,
  )
  let cfg = @core.OptimizationConfig::new(3.0, 800.0)
  let demands = [
    @core.DemandItem::new("DEMO-A", 3800.0, 2, "演示构件 A"),
    @core.DemandItem::new("DEMO-B", 2700.0, 2, "演示构件 B"),
    @core.DemandItem::new("DEMO-C", 1500.0, 1, "演示构件 C"),
  ]

  let summary = match
    @optimizer.try_optimize_cutting_stock(stock, demands, cfg) {
    Ok(value) => value
    Err(_) => abort("Demo input validation failed")
  }
  let cost = @pricing.evaluate_cost(
    stock,
    summary,
    @pricing.QuotaStandard::default_rebar(),
    @pricing.ScrapMarketParam::default(),
  )

  println("Input")
  print_metric("stock length", stock.length_mm.to_string() + " mm")
  print_metric("demand items", demands.length().to_string())
  print_metric("kerf", cfg.kerf_width_mm.to_string() + " mm")
  println("Result")
  print_metric("stock bars", summary.total_stocks_used.to_string())
  print_metric(
    "demanded length",
    summary.total_demanded_length_mm.to_string() + " mm",
  )
  print_metric(
    "reusable remnant",
    summary.total_reusable_length_mm.to_string() + " mm",
  )
  print_metric("scrap", summary.total_scrap_length_mm.to_string() + " mm")
  print_metric("waste ratio", (summary.waste_ratio * 100.0).to_string() + " %")
  println("Cost model")
  print_metric(
    "net material cost",
    cost.net_material_cost.to_string() + " yuan",
  )
  print_metric(
    "comprehensive unit price",
    cost.comprehensive_unit_price.to_string() + " yuan/t",
  )
  print_metric(
    "assumed baseline difference",
    cost.cost_saved_amount.to_string() + " yuan",
  )
  println("Demo completed successfully.")
}
