// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0

///|
test "cost quota evaluation with scrap recovery" {
  let stock = @core.StockMaterial::new(
    "HRB400E-D25", "三级螺纹钢Φ25", 9000.0, 3.85, 3850.0,
  )
  let cfg = @core.OptimizationConfig::new(3.0, 800.0)

  let demands = [
    @core.DemandItem::new("A", 3000.0, 3, "框架梁上部筋"),
    @core.DemandItem::new("B", 2500.0, 3, "框架梁下部筋"),
    @core.DemandItem::new("C", 1800.0, 2, "柱箍筋预制"),
  ]

  let opt_summary = @optimizer.optimize_cutting_stock(stock, demands, cfg)
  let quota = QuotaStandard::default_rebar()
  let scrap_mkt = ScrapMarketParam::default()

  let cost = evaluate_cost(stock, opt_summary, quota, scrap_mkt)

  assert_eq(cost.subtotal_direct_cost > 0.0, true)
  assert_eq(cost.total_project_cost > 0.0, true)
  assert_eq(cost.comprehensive_unit_price > 0.0, true)
  assert_eq(
    cost.gross_procured_weight_ton >= cost.net_demanded_weight_ton,
    true,
  )

  let expected_net_mat = cost.material_gross_cost -
    cost.scrap_recovery_income -
    cost.reusable_inventory_credit
  let diff = (cost.net_material_cost - expected_net_mat).abs()
  assert_eq(diff < 1.0e-6, true)
}

///|
test "zero tax rate scenario evaluation" {
  let stock = @core.StockMaterial::new(
    "HRB400E-D20", "螺纹钢Φ20", 9000.0, 2.47, 3900.0,
  )
  let cfg = @core.OptimizationConfig::default()
  let demands = [@core.DemandItem::new("D1", 4000.0, 2, "次梁主筋")]

  let opt_summary = @optimizer.optimize_cutting_stock(stock, demands, cfg)
  let quota_zero_tax = QuotaStandard::new(
    "010515001", "免税工程现浇钢筋", 600.0, 150.0, 0.02, 0.08, 0.05, 0.0,
  )
  let scrap_mkt = ScrapMarketParam::default()

  let cost = evaluate_cost(stock, opt_summary, quota_zero_tax, scrap_mkt)
  assert_eq(cost.tax_amount, 0.0)
  let pre_tax = cost.subtotal_direct_cost + cost.management_fee + cost.profit
  let diff = (cost.total_project_cost - pre_tax).abs()
  assert_eq(diff < 1.0e-6, true)
}

///|
test "empty demand cost evaluation produces zero safe values" {
  let stock = @core.StockMaterial::new(
    "S-Empty", "母材9m", 9000.0, 3.85, 3850.0,
  )
  let empty_summary = @core.OptimizationSummary::empty()
  let quota = QuotaStandard::default_rebar()
  let scrap_mkt = ScrapMarketParam::default()

  let cost = evaluate_cost(stock, empty_summary, quota, scrap_mkt)
  assert_eq(cost.net_demanded_weight_ton, 0.0)
  assert_eq(cost.gross_procured_weight_ton, 0.0)
  assert_eq(cost.total_project_cost, 0.0)
  assert_eq(cost.comprehensive_unit_price, 0.0)
}

///|
test "illustrative CLI cost benchmark is reproducible" {
  let stock = @core.StockMaterial::new(
    "HRB400E-D25", "螺纹钢Φ25", 9000.0, 3.85, 3850.0,
  )
  let cfg = @core.OptimizationConfig::new(3.0, 800.0)
  let demands = [
    @core.DemandItem::new("KZ-01", 3800.0, 8, "框架柱基础插筋"),
    @core.DemandItem::new("KZ-02", 2700.0, 12, "框架柱二层主筋"),
    @core.DemandItem::new("KL-01", 2400.0, 10, "框架梁跨中下部通长筋"),
    @core.DemandItem::new("KL-02", 1500.0, 6, "次梁支座负弯矩加强筋"),
  ]

  let summary = @optimizer.optimize_cutting_stock(stock, demands, cfg)
  let cost = evaluate_cost(
    stock,
    summary,
    QuotaStandard::default_rebar(),
    ScrapMarketParam::default(),
  )
  assert_eq((cost.net_material_cost - 1450.658873125).abs() < 1.0e-9, true)
  assert_eq(
    (cost.comprehensive_unit_price - 5658.0557197938415).abs() < 1.0e-9,
    true,
  )
  assert_eq((cost.cost_saved_amount + 33.19268980046263).abs() < 1.0e-9, true)
}

///|
test "independent hand-worked cost example checks formula assumptions" {
  // 10 mm stock, 8 mm demand, 1 mm kerf and 1 mm scrap. At 1000 kg/m,
  // each mm is 0.001 t. This summary is deliberately not from optimizer.
  let stock = @core.StockMaterial::new("S", "synthetic", 10.0, 1000.0, 1000.0)
  let summary = @core.OptimizationSummary::new(
    1,
    10.0,
    8.0,
    1.0,
    0.0,
    1.0,
    0.2,
    0.0,
    [],
  )
  let quota = QuotaStandard::new(
    "example", "hand worked", 100.0, 0.0, 0.25, 0.1, 0.0, 0.0,
  )
  let market = ScrapMarketParam::new(100.0, 0.0)
  let cost = evaluate_cost(stock, summary, quota, market)
  assert_eq(cost.net_demanded_weight_ton, 0.008)
  assert_eq(cost.gross_procured_weight_ton, 0.01)
  assert_eq(cost.material_gross_cost, 10.0)
  assert_eq(cost.scrap_recovery_income, 0.2)
  assert_eq(cost.net_material_cost, 9.8)
  assert_eq(cost.labor_cost, 1.0)
  assert_eq(cost.management_fee, 0.1)
  assert_eq(cost.total_project_cost, 10.9)
  assert_eq(cost.comprehensive_unit_price, 1362.5)
  assert_eq(cost.quota_baseline_cost, 11.1)
  assert_eq((cost.cost_saved_amount - 0.2).abs() < 1.0e-9, true)
}

///|
test "independent cost example includes reusable credit profit and tax" {
  // Hand calculation: 10 mm stock, 7 mm demand, 1 mm kerf, 2 mm
  // reusable remnant. Each millimetre weighs 0.001 t. This summary is
  // independent of the cutting-stock solver.
  let stock = @core.StockMaterial::new("S", "synthetic", 10.0, 1000.0, 1000.0)
  let summary = @core.OptimizationSummary::new(
    1,
    10.0,
    7.0,
    1.0,
    2.0,
    0.0,
    0.1,
    0.2,
    [],
  )
  let quota = QuotaStandard::new(
    "example", "hand worked", 100.0, 0.0, 0.0, 0.1, 0.1, 0.1,
  )
  let market = ScrapMarketParam::new(100.0, 0.5)
  let cost = evaluate_cost(stock, summary, quota, market)

  assert_eq(cost.scrap_recovery_income, 0.1)
  assert_eq(cost.reusable_inventory_credit, 1.0)
  assert_eq(cost.net_material_cost, 8.9)
  assert_eq(cost.subtotal_direct_cost, 9.9)
  assert_eq(cost.management_fee, 0.1)
  assert_eq(cost.profit, 1.0)
  assert_eq(cost.tax_amount, 1.1)
  assert_eq(cost.total_project_cost, 12.1)
  assert_eq((cost.comprehensive_unit_price - 12.1 / 0.007).abs() < 1.0e-9, true)
  assert_eq((cost.quota_baseline_cost - 9.4017).abs() < 1.0e-9, true)
}
