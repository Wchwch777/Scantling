// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0

///|
test "domain types constructor and default config" {
  let mat = StockMaterial::new(
    "HRB400E-D25", "螺纹钢Φ25", 9000.0, 3.85, 3850.0,
  )
  assert_eq(mat.id, "HRB400E-D25")
  assert_eq(mat.length_mm, 9000.0)

  let cfg = OptimizationConfig::default()
  assert_eq(cfg.kerf_width_mm, 3.0)
  assert_eq(cfg.min_reusable_length_mm, 800.0)

  let demand = DemandItem::new("D1", 2400.0, 5, "柱插筋")
  assert_eq(demand.quantity, 5)
  assert_eq(demand.tag, "柱插筋")
}

///|
test "validation detects oversized demand piece" {
  let stock = StockMaterial::new("S1", "母材9m", 9000.0, 3.85, 3850.0)
  let cfg = OptimizationConfig::default()
  let demands = [
    DemandItem::new("D-Valid", 3000.0, 2, "正常梁筋"),
    DemandItem::new("D-Oversized", 9500.0, 1, "超长异常筋"),
  ]
  let errs = validate_inputs(stock, demands, cfg)
  assert_eq(errs.length(), 1)
  assert_eq(
    errs[0],
    ValidationError::PieceExceedsStockLength("D-Oversized", 9500.0, 9000.0),
  )
}

///|
test "validation detects non-positive stock length and quantity" {
  let invalid_stock = StockMaterial::new(
    "S0", "母材错误", 0.0, 3.85, 3850.0,
  )
  let invalid_cfg = OptimizationConfig::new(-1.0, 800.0)
  let demands = [DemandItem::new("D-BadQty", 2000.0, 0, "零数量构件")]

  let errs = validate_inputs(invalid_stock, demands, invalid_cfg)
  assert_eq(errs.length(), 3)
}

///|
test "empty summary constructor defaults" {
  let empty = OptimizationSummary::empty()
  assert_eq(empty.total_stocks_used, 0)
  assert_eq(empty.total_demanded_length_mm, 0.0)
  assert_eq(empty.patterns.length(), 0)
}
