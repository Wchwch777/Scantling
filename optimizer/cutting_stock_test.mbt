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

///|
test "best fit considers a valid bar above one trillion mm" {
  // Synthetic scale boundary: remaining space after placement exceeds 1e12.
  let stock = @core.StockMaterial::new(
    "S-Large", "synthetic stock", 5000000000000.0, 1.0, 1.0,
  )
  let cfg = @core.OptimizationConfig::new(0.0, 0.0)
  let demands = [
    @core.DemandItem::new("D-Large", 1500000000000.0, 2, "synthetic cuts"),
  ]

  let result = solve_best_fit_decreasing(stock, demands, cfg)
  assert_eq(result.total_stocks_used, 1)
  assert_eq(result.patterns[0].cuts.length(), 2)
  assert_eq(result.patterns[0].remnant_length_mm, 2000000000000.0)
}

///|
test "heuristic winner preserves pieces and physical length" {
  let stock = @core.StockMaterial::new("S-Rule", "stock", 10.0, 1.0, 1.0)
  let cfg = @core.OptimizationConfig::new(1.0, 3.0)
  let demands = [
    @core.DemandItem::new("A", 6.0, 1, "long"),
    @core.DemandItem::new("B", 3.0, 2, "short"),
    @core.DemandItem::new("C", 2.0, 1, "shorter"),
  ]
  let result = optimize_cutting_stock(stock, demands, cfg)
  let ffd = solve_first_fit_decreasing(stock, demands, cfg)
  let bfd = solve_best_fit_decreasing(stock, demands, cfg)
  assert_eq(result.total_stocks_used <= ffd.total_stocks_used, true)
  assert_eq(result.total_stocks_used <= bfd.total_stocks_used, true)
  let mut placed = 0
  let mut consumed = 0.0
  for pattern in result.patterns {
    placed = placed + pattern.cuts.length()
    assert_eq(
      pattern.used_length_mm + pattern.kerf_loss_mm + pattern.remnant_length_mm,
      pattern.stock_length_mm,
    )
    assert_eq(pattern.remnant_length_mm >= 0.0, true)
    consumed = consumed + pattern.used_length_mm
  }
  assert_eq(placed, 4)
  assert_eq(consumed, 14.0)
}

///|
test "illustrative CLI benchmark is reproducible" {
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

  match try_optimize_cutting_stock(stock, demands, cfg) {
    Err(_) => fail("illustrative benchmark input must be valid")
    Ok(result) => {
      assert_eq(result.total_stocks_used, 12)
      assert_eq(result.total_demanded_length_mm, 95800.0)
      assert_eq(result.total_kerf_loss_mm, 72.0)
      assert_eq(result.total_reusable_length_mm, 11255.0)
      assert_eq(result.total_scrap_length_mm, 873.0)
    }
  }
}

///|
test "FFD and BFD are not globally optimal on a small exact instance" {
  // Total demand is 20, so two 10 mm bars are a lower bound and feasible:
  // (6 + 2 + 2) and (5 + 3 + 2). Both decreasing heuristics use three.
  let stock = @core.StockMaterial::new("S10", "10 mm", 10.0, 1.0, 1.0)
  let cfg = @core.OptimizationConfig::new(0.0, 1.0)
  let demands = [
    @core.DemandItem::new("6", 6.0, 1, ""),
    @core.DemandItem::new("5", 5.0, 1, ""),
    @core.DemandItem::new("3", 3.0, 1, ""),
    @core.DemandItem::new("2", 2.0, 3, ""),
  ]
  assert_eq(
    solve_first_fit_decreasing(stock, demands, cfg).total_stocks_used,
    3,
  )
  assert_eq(solve_best_fit_decreasing(stock, demands, cfg).total_stocks_used, 3)
  assert_eq(optimize_cutting_stock(stock, demands, cfg).total_stocks_used, 3)
}

///|
test "BFD considers feasible remaining space above one trillion mm" {
  let stock = @core.StockMaterial::new(
    "Huge", "synthetic boundary", 4.0e12, 1.0, 1.0,
  )
  let cfg = @core.OptimizationConfig::new(0.0, 1.0)
  let demands = [@core.DemandItem::new("D", 1.0, 2, "")]
  let result = solve_best_fit_decreasing(stock, demands, cfg)
  assert_eq(result.total_stocks_used, 1)
  assert_eq(result.patterns[0].cuts.length(), 2)
}

///|
test "heuristic patterns conserve stock length with kerf" {
  let stock = @core.StockMaterial::new("S", "9m", 9000.0, 1.0, 1.0)
  let cfg = @core.OptimizationConfig::new(3.0, 800.0)
  let demands = [
    @core.DemandItem::new("A", 4000.0, 2, ""),
    @core.DemandItem::new("B", 1000.0, 2, ""),
  ]
  let summaries = [
    solve_first_fit_decreasing(stock, demands, cfg),
    solve_best_fit_decreasing(stock, demands, cfg),
  ]
  for summary in summaries {
    let mut cuts = 0
    for pattern in summary.patterns {
      cuts = cuts + pattern.cuts.length()
      assert_eq(
        pattern.used_length_mm +
        pattern.kerf_loss_mm +
        pattern.remnant_length_mm,
        9000.0,
      )
      assert_eq(pattern.remnant_length_mm >= 0.0, true)
      assert_eq(
        pattern.kerf_loss_mm,
        (pattern.cuts.length() - 1).to_double() * 3.0,
      )
    }
    assert_eq(cuts, 4)
    assert_eq(
      summary.total_demanded_length_mm +
      summary.total_kerf_loss_mm +
      summary.total_reusable_length_mm +
      summary.total_scrap_length_mm,
      summary.total_stock_length_mm,
    )
  }
}
