// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0

///|
test "expand demands into individual pieces" {
  let d1 = @core.DemandItem::new("D1", 2000.0, 2, "柱主筋")
  let d2 = @core.DemandItem::new("D2", 1500.0, 1, "梁腰筋")
  let pieces = expand_demands([d1, d2])
  assert_eq(pieces.length(), 3)
}

///|
test "heuristic cutting stock solver with standard 9m rebar" {
  let stock = @core.StockMaterial::new(
    "HRB400E-D25", "螺纹钢Φ25", 9000.0, 3.85, 3850.0,
  )
  let cfg = @core.OptimizationConfig::new(3.0, 800.0)

  let demands = [
    @core.DemandItem::new("A", 3000.0, 2, "框架梁上部通长筋"),
    @core.DemandItem::new("B", 2900.0, 2, "框架梁下部通长筋"),
    @core.DemandItem::new("C", 3100.0, 1, "柱锚固插筋"),
  ]

  let result = optimize_cutting_stock(stock, demands, cfg)

  assert_eq(result.total_stocks_used, 2)
  assert_eq(result.total_demanded_length_mm, 14900.0)
  assert_eq(result.patterns.length(), 2)

  let mut total_placed_cuts = 0
  for p in result.patterns {
    total_placed_cuts = total_placed_cuts + p.cuts.length()
  }
  assert_eq(total_placed_cuts, 5)
}

///|
test "exact zero-remnant packing scenario" {
  // 3 根 2998mm 切件 + 2 处 3mm 锯口 = 2998 * 3 + 6 = 9000mm 完美利用
  let stock = @core.StockMaterial::new(
    "S-Exact", "定尺9m", 9000.0, 2.0, 4000.0,
  )
  let cfg = @core.OptimizationConfig::new(3.0, 800.0)
  let demands = [@core.DemandItem::new("E1", 2998.0, 3, "精确匹配构件")]

  let result = optimize_cutting_stock(stock, demands, cfg)
  assert_eq(result.total_stocks_used, 1)
  assert_eq(result.patterns[0].remnant_length_mm, 0.0)
  assert_eq(result.patterns[0].kerf_loss_mm, 6.0)
  assert_eq(result.total_scrap_length_mm, 0.0)
}

///|
test "kerf loss accumulation with multiple cuts" {
  // 1 根 9000mm 原材切出 10 段 800mm 构件
  // 锯口损失 = (10 - 1) * 3 = 27mm
  // 余料 = 9000 - 8000 - 27 = 973mm (> 800mm，计为可复用)
  let stock = @core.StockMaterial::new(
    "S-Kerf", "定尺9m", 9000.0, 2.0, 4000.0,
  )
  let cfg = @core.OptimizationConfig::new(3.0, 800.0)
  let demands = [@core.DemandItem::new("K1", 800.0, 10, "密集切件")]

  let result = optimize_cutting_stock(stock, demands, cfg)
  assert_eq(result.total_stocks_used, 1)
  assert_eq(result.patterns[0].kerf_loss_mm, 27.0)
  assert_eq(result.patterns[0].remnant_length_mm, 973.0)
  assert_eq(result.patterns[0].is_reusable, true)
}

///|
test "empty demands yields empty summary" {
  let stock = @core.StockMaterial::new(
    "S-Empty", "定尺9m", 9000.0, 2.0, 4000.0,
  )
  let cfg = @core.OptimizationConfig::default()
  let result = optimize_cutting_stock(stock, [], cfg)
  assert_eq(result.total_stocks_used, 0)
  assert_eq(result.patterns.length(), 0)
}

///|
test "checked optimizer rejects invalid input" {
  let stock = @core.StockMaterial::new(
    "S-Invalid", "定尺9m", 9000.0, 2.0, 4000.0,
  )
  let demands = [@core.DemandItem::new("D-Negative", -1.0, 1, "非法长度")]
  let cfg = @core.OptimizationConfig::new(3.0, -1.0)

  match try_optimize_cutting_stock(stock, demands, cfg) {
    Err(errors) => assert_eq(errors.length(), 2)
    Ok(_) => fail("invalid input must be rejected before solving")
  }
}
