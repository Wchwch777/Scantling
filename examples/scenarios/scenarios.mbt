// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0
//
// Four synthetic material cases through the same public MoonBit packages.

///|
priv struct DemoScenario {
  label : String
  stock : @core.StockMaterial
  demands : Array[@core.DemandItem]
  config : @core.OptimizationConfig
  quota : @pricing.QuotaStandard
  recovery : @pricing.ScrapMarketParam
}

///|
fn building_case() -> DemoScenario {
  {
    label: "Building profile (assumed rebar)",
    stock: @core.StockMaterial::new(
      "REBAR", "示例钢筋", 9000.0, 3.85, 3850.0,
    ),
    demands: [
      @core.DemandItem::new("A", 3800.0, 2, "演示构件 A"),
      @core.DemandItem::new("B", 2700.0, 2, "演示构件 B"),
      @core.DemandItem::new("C", 1500.0, 1, "演示构件 C"),
    ],
    config: @core.OptimizationConfig::new(3.0, 800.0),
    quota: @pricing.QuotaStandard::default_rebar(),
    recovery: @pricing.ScrapMarketParam::default(),
  }
}

///|
fn timber_case() -> DemoScenario {
  {
    label: "Furniture timber (synthetic)",
    stock: @core.StockMaterial::new("WOOD", "示例木料", 6000.0, 2.0, 2000.0),
    demands: [
      @core.DemandItem::new("SIDE", 2500.0, 2, "侧板料"),
      @core.DemandItem::new("BRACE", 900.0, 1, "短撑料"),
    ],
    config: @core.OptimizationConfig::new(4.0, 500.0),
    quota: @pricing.QuotaStandard::new(
      "WOOD-DEMO", "木料切割", 100.0, 20.0, 0.02, 0.0, 0.0, 0.0,
    ),
    recovery: @pricing.ScrapMarketParam::new(0.0, 0.0),
  }
}

///|
fn pipe_case() -> DemoScenario {
  {
    label: "Workshop pipe (synthetic)",
    stock: @core.StockMaterial::new("PIPE", "示例管材", 5000.0, 1.0, 3000.0),
    demands: [@core.DemandItem::new("SECTION", 2400.0, 2, "管段")],
    config: @core.OptimizationConfig::new(2.0, 150.0),
    quota: @pricing.QuotaStandard::new(
      "PIPE-DEMO", "管材切割", 50.0, 10.0, 0.01, 0.0, 0.0, 0.0,
    ),
    recovery: @pricing.ScrapMarketParam::new(1000.0, 0.5),
  }
}

///|
fn cable_case() -> DemoScenario {
  {
    label: "Cable reel (synthetic exact fit, zero kerf)",
    stock: @core.StockMaterial::new(
      "CABLE", "示例线缆", 1000.0, 0.2, 5000.0,
    ),
    demands: [
      @core.DemandItem::new("LONG", 600.0, 1, "长线段"),
      @core.DemandItem::new("SHORT", 400.0, 1, "短线段"),
    ],
    config: @core.OptimizationConfig::new(0.0, 100.0),
    quota: @pricing.QuotaStandard::new(
      "CABLE-DEMO", "线缆裁切", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    ),
    recovery: @pricing.ScrapMarketParam::new(0.0, 0.0),
  }
}

///|
fn run_case(
  scenario : DemoScenario,
) -> (@core.OptimizationSummary, @pricing.CostBreakdown) {
  let summary = match
    @optimizer.try_optimize_cutting_stock(
      scenario.stock,
      scenario.demands,
      scenario.config,
    ) {
    Ok(value) => value
    Err(_) => abort("Demo input validation failed")
  }
  let cost = match
    @pricing.try_evaluate_cost(
      scenario.stock,
      summary,
      scenario.quota,
      scenario.recovery,
    ) {
    Ok(value) => value
    Err(_) => abort("Demo cost input validation failed")
  }
  (summary, cost)
}

///|
fn print_case(scenario : DemoScenario) -> Unit {
  let (summary, cost) = run_case(scenario)
  println("\n" + scenario.label)
  println("  stock length: " + scenario.stock.length_mm.to_string() + " mm")
  println("  kerf: " + scenario.config.kerf_width_mm.to_string() + " mm")
  println("  stock bars: " + summary.total_stocks_used.to_string())
  println("  demanded: " + summary.total_demanded_length_mm.to_string() + " mm")
  println("  kerf loss: " + summary.total_kerf_loss_mm.to_string() + " mm")
  println(
    "  reusable remnant: " +
    summary.total_reusable_length_mm.to_string() +
    " mm",
  )
  println(
    "  scrap remnant: " + summary.total_scrap_length_mm.to_string() + " mm",
  )
  println(
    "  net material cost: " + cost.net_material_cost.to_string() + " yuan",
  )
  println(
    "  modeled total cost: " + cost.total_project_cost.to_string() + " yuan",
  )
}

///|
pub fn run_all() -> Unit {
  println("Scantling: one-dimensional cutting and parameterized cost")
  println("First four cases use synthetic input assumptions.")
  println("The final cases are sourced historical-demand relaxations.")
  println("Units: length mm; synthetic cost cases use kg/m and yuan/ton.")
  println(
    "FFD/BFD are heuristics; outputs do not prove a global optimum or actual savings.",
  )
  print_case(building_case())
  print_case(timber_case())
  print_case(pipe_case())
  print_case(cable_case())
  run_paper_tube_f2()
  run_chemical_fiber_06()
}
