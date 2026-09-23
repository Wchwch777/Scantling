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
