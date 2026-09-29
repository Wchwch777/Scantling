// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0

///|
test "four synthetic material cases preserve quantity and physical length" {
  for scenario in [building_case(), timber_case(), pipe_case(), cable_case()] {
    let (summary, cost) = run_case(scenario)
    let mut expected_pieces = 0
    let mut expected_length = 0.0
    for demand in scenario.demands {
      expected_pieces = expected_pieces + demand.quantity
      expected_length = expected_length +
        demand.length_mm * demand.quantity.to_double()
    }
    let mut actual_pieces = 0
    for pattern in summary.patterns {
      actual_pieces = actual_pieces + pattern.cuts.length()
      assert_eq(
        (pattern.used_length_mm +
        pattern.kerf_loss_mm +
        pattern.remnant_length_mm -
        pattern.stock_length_mm).abs() <
        1.0e-9,
        true,
      )
      assert_eq(
        pattern.kerf_loss_mm,
        (pattern.cuts.length() - 1).to_double() * scenario.config.kerf_width_mm,
      )
    }
    assert_eq(actual_pieces, expected_pieces)
    assert_eq(summary.total_demanded_length_mm, expected_length)
    assert_eq(
      (summary.total_stock_length_mm -
      summary.total_demanded_length_mm -
      summary.total_kerf_loss_mm -
      summary.total_reusable_length_mm -
      summary.total_scrap_length_mm).abs() <
      1.0e-9,
      true,
    )
    assert_eq(
      (cost.net_material_cost -
      cost.material_gross_cost +
      cost.scrap_recovery_income +
      cost.reusable_inventory_credit).abs() <
      1.0e-9,
      true,
    )
  }
}

///|
test "published paper-tube F2 case preserves sourced demand and length" {
  let (stock, demands, config) = paper_tube_f2_inputs()
  assert_eq(stock.length_mm, 1800.0)
  assert_eq(demands.length(), 15)
  let mut expected_pieces = 0
  let mut expected_length = 0.0
  for demand in demands {
    expected_pieces = expected_pieces + demand.quantity
    expected_length = expected_length +
      demand.length_mm * demand.quantity.to_double()
  }
  assert_eq(expected_pieces, 1500)
  assert_eq(expected_length, 247330.0)

  let summary = match
    @optimizer.try_optimize_cutting_stock(stock, demands, config) {
    Ok(value) => value
    Err(_) => abort("Published paper-tube F2 replay input validation failed")
  }
  assert_eq(summary.total_demanded_length_mm, 247330.0)
  assert_eq(summary.total_kerf_loss_mm, 0.0)
  assert_eq(summary.total_stocks_used, 139)
  assert_eq(
    summary.total_stock_length_mm,
    summary.total_stocks_used.to_double() * 1800.0,
  )
  assert_eq(
    summary.total_stock_length_mm - summary.total_demanded_length_mm,
    2870.0,
  )
  assert_eq(
    (summary.total_stock_length_mm -
    summary.total_demanded_length_mm -
    summary.total_kerf_loss_mm -
    summary.total_scrap_length_mm -
    summary.total_reusable_length_mm).abs() <
    1.0e-9,
    true,
  )
}

///|
test "published chemical-fiber instance 06 preserves demand in both stock variants" {
  for stock_length in [9080.0, 5180.0] {
    let (stock, demands, config) = chemical_fiber_06_inputs(stock_length)
    assert_eq(stock.length_mm, stock_length)
    assert_eq(demands.length(), 6)
    let mut expected_pieces = 0
    let mut expected_length = 0.0
    for demand in demands {
      expected_pieces = expected_pieces + demand.quantity
      expected_length = expected_length +
        demand.length_mm * demand.quantity.to_double()
    }
    assert_eq(expected_pieces, 198)
    assert_eq(expected_length, 167438.0)

    let summary = match
      @optimizer.try_optimize_cutting_stock(stock, demands, config) {
      Ok(value) => value
      Err(_) => abort("Published chemical-fiber instance validation failed")
    }
    assert_eq(summary.total_demanded_length_mm, 167438.0)
    assert_eq(summary.total_kerf_loss_mm, 0.0)
    if stock_length == 9080.0 {
      assert_eq(summary.total_stocks_used, 19)
      assert_eq(
        summary.total_stock_length_mm - summary.total_demanded_length_mm,
        5082.0,
      )
    } else {
      assert_eq(summary.total_stocks_used, 34)
      assert_eq(
        summary.total_stock_length_mm - summary.total_demanded_length_mm,
        8682.0,
      )
    }
    assert_eq(
      (summary.total_stock_length_mm -
      summary.total_demanded_length_mm -
      summary.total_kerf_loss_mm -
      summary.total_scrap_length_mm -
      summary.total_reusable_length_mm).abs() <
      1.0e-9,
      true,
    )
  }
}

///|
test "synthetic cable zero-kerf exact fit has no remnant or recovery" {
  let (summary, cost) = run_case(cable_case())
  assert_eq(summary.total_stocks_used, 1)
  assert_eq(summary.total_demanded_length_mm, 1000.0)
  assert_eq(summary.total_kerf_loss_mm, 0.0)
  assert_eq(summary.total_reusable_length_mm, 0.0)
  assert_eq(summary.total_scrap_length_mm, 0.0)
  assert_eq(cost.material_gross_cost, 1.0)
  assert_eq(cost.total_project_cost, 1.0)
}

///|
test "synthetic timber and pipe cases lock kerf remnant and cost assumptions" {
  let (wood, wood_cost) = run_case(timber_case())
  assert_eq(wood.total_stocks_used, 1)
  assert_eq(wood.total_demanded_length_mm, 5900.0)
  assert_eq(wood.total_kerf_loss_mm, 8.0)
  assert_eq(wood.total_scrap_length_mm, 92.0)
  assert_eq(wood.total_reusable_length_mm, 0.0)
  assert_eq(wood_cost.material_gross_cost, 24.0)
  assert_eq(wood_cost.net_material_cost, 24.0)
  assert_eq((wood_cost.total_project_cost - 25.44).abs() < 1.0e-9, true)

  let (pipe, pipe_cost) = run_case(pipe_case())
  assert_eq(pipe.total_stocks_used, 1)
  assert_eq(pipe.total_demanded_length_mm, 4800.0)
  assert_eq(pipe.total_kerf_loss_mm, 2.0)
  assert_eq(pipe.total_reusable_length_mm, 198.0)
  assert_eq(pipe.total_scrap_length_mm, 0.0)
  assert_eq(pipe_cost.material_gross_cost, 15.0)
  assert_eq((pipe_cost.scrap_recovery_income - 0.002).abs() < 1.0e-9, true)
  assert_eq((pipe_cost.reusable_inventory_credit - 0.297).abs() < 1.0e-9, true)
  assert_eq((pipe_cost.net_material_cost - 14.701).abs() < 1.0e-9, true)
  assert_eq((pipe_cost.total_project_cost - 15.001).abs() < 1.0e-9, true)
}
