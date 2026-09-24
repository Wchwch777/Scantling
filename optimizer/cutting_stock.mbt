// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0
//
// 建筑工程型材套裁启发式优化求解引擎 (FFD & Best-Fit 启发式套裁)

///|
priv struct BarState {
  stock_id : String
  stock_length : Double
  cuts : Array[@core.CutPiece]
  mut used_length : Double
  mut kerf_loss : Double
}

///|
fn BarState::new(stock : @core.StockMaterial) -> BarState {
  {
    stock_id: stock.id,
    stock_length: stock.length_mm,
    cuts: [],
    used_length: 0.0,
    kerf_loss: 0.0,
  }
}

///|
fn BarState::can_fit(
  self : BarState,
  piece_len : Double,
  kerf_width : Double,
) -> Bool {
  let extra_kerf = if self.cuts.length() > 0 { kerf_width } else { 0.0 }
  self.used_length + self.kerf_loss + piece_len + extra_kerf <=
  self.stock_length
}

///|
fn BarState::add_cut(
  self : BarState,
  piece : @core.CutPiece,
  kerf_width : Double,
) -> Unit {
  if self.cuts.length() > 0 {
    self.kerf_loss = self.kerf_loss + kerf_width
  }
  self.cuts.push(piece)
  self.used_length = self.used_length + piece.length_mm
}

///|
fn BarState::remaining_space(self : BarState) -> Double {
  self.stock_length - (self.used_length + self.kerf_loss)
}

///|
fn BarState::to_pattern(
  self : BarState,
  min_reusable_length : Double,
) -> @core.CutPattern {
  let remnant = self.remaining_space()
  let is_reusable = remnant >= min_reusable_length
  @core.CutPattern::new(
    self.stock_id,
    self.stock_length,
    self.cuts,
    self.used_length,
    self.kerf_loss,
    remnant,
    is_reusable,
  )
}

///|
/// 将清单需求展平为待排料切件集合
pub fn expand_demands(
  demands : Array[@core.DemandItem],
) -> Array[@core.CutPiece] {
  let pieces : Array[@core.CutPiece] = []
  for d in demands {
    for _ in 0..<d.quantity {
      pieces.push(@core.CutPiece::new(d.id, d.length_mm))
    }
  }
  pieces
}

///|
/// 按构件定尺降序排列切件（长料优先排布原则）
pub fn sort_pieces_descending(pieces : Array[@core.CutPiece]) -> Unit {
  pieces.sort_by(fn(a, b) {
    if a.length_mm > b.length_mm {
      -1
    } else if a.length_mm < b.length_mm {
      1
    } else {
      0
    }
  })
}

///|
fn build_summary(
  bars : Array[BarState],
  config : @core.OptimizationConfig,
) -> @core.OptimizationSummary {
  let patterns : Array[@core.CutPattern] = []
  let mut total_stocks = 0
  let mut total_stock_length = 0.0
  let mut total_demanded = 0.0
  let mut total_kerf = 0.0
  let mut total_reusable = 0.0
  let mut total_scrap = 0.0

  for bar in bars {
    let pat = bar.to_pattern(config.min_reusable_length_mm)
    patterns.push(pat)
    total_stocks = total_stocks + 1
    total_stock_length = total_stock_length + pat.stock_length_mm
    total_demanded = total_demanded + pat.used_length_mm
    total_kerf = total_kerf + pat.kerf_loss_mm
    if pat.is_reusable {
      total_reusable = total_reusable + pat.remnant_length_mm
    } else {
      total_scrap = total_scrap + pat.remnant_length_mm
    }
  }

  let waste_ratio = if total_stock_length > 0.0 {
    (total_kerf + total_scrap) / total_stock_length
  } else {
    0.0
  }
  let reusable_ratio = if total_stock_length > 0.0 {
    total_reusable / total_stock_length
  } else {
    0.0
  }

  @core.OptimizationSummary::new(
    total_stocks, total_stock_length, total_demanded, total_kerf, total_reusable,
    total_scrap, waste_ratio, reusable_ratio, patterns,
  )
}

///|
/// 首次适应降序套裁算法 (First-Fit Decreasing, FFD)
fn solve_first_fit_decreasing_unchecked(
  stock : @core.StockMaterial,
  demands : Array[@core.DemandItem],
  config : @core.OptimizationConfig,
) -> @core.OptimizationSummary {
  let pieces = expand_demands(demands)
  if pieces.length() == 0 {
    return @core.OptimizationSummary::empty()
  }
  sort_pieces_descending(pieces)

  let bars : Array[BarState] = []
  for piece in pieces {
    let mut placed = false
    for bar in bars {
      if bar.can_fit(piece.length_mm, config.kerf_width_mm) {
        bar.add_cut(piece, config.kerf_width_mm)
        placed = true
        break
      }
    }
    if !placed {
      let new_bar = BarState::new(stock)
      new_bar.add_cut(piece, config.kerf_width_mm)
      bars.push(new_bar)
    }
  }

  build_summary(bars, config)
}

///|
/// 最佳适应降序套裁算法 (Best-Fit Decreasing, BFD)
/// 在已有原材中寻找能容纳当前切件且剩余空间最小的母材，极大程度压制零碎残余
fn solve_best_fit_decreasing_unchecked(
  stock : @core.StockMaterial,
  demands : Array[@core.DemandItem],
  config : @core.OptimizationConfig,
) -> @core.OptimizationSummary {
  let pieces = expand_demands(demands)
  if pieces.length() == 0 {
    return @core.OptimizationSummary::empty()
  }
  sort_pieces_descending(pieces)

  let bars : Array[BarState] = []
  for piece in pieces {
    let mut best_index = -1
    let mut min_remaining_after = 1.0e12

    for i = 0; i < bars.length(); i = i + 1 {
      let bar = bars[i]
      if bar.can_fit(piece.length_mm, config.kerf_width_mm) {
        let extra_kerf = if bar.cuts.length() > 0 {
          config.kerf_width_mm
        } else {
          0.0
        }
        let space_after = bar.remaining_space() - piece.length_mm - extra_kerf
        if space_after < min_remaining_after {
          min_remaining_after = space_after
          best_index = i
        }
      }
    }

    if best_index >= 0 {
      bars[best_index].add_cut(piece, config.kerf_width_mm)
    } else {
      let new_bar = BarState::new(stock)
      new_bar.add_cut(piece, config.kerf_width_mm)
      bars.push(new_bar)
    }
  }

  build_summary(bars, config)
}

///|
/// 带类型错误信息的 FFD 求解入口。
pub fn try_solve_first_fit_decreasing(
  stock : @core.StockMaterial,
  demands : Array[@core.DemandItem],
  config : @core.OptimizationConfig,
) -> Result[@core.OptimizationSummary, Array[@core.ValidationError]] {
  let errors = @core.validate_inputs(stock, demands, config)
  if errors.length() > 0 {
    Err(errors)
  } else {
    Ok(solve_first_fit_decreasing_unchecked(stock, demands, config))
  }
}

///|
/// 带类型错误信息的 BFD 求解入口。
pub fn try_solve_best_fit_decreasing(
  stock : @core.StockMaterial,
  demands : Array[@core.DemandItem],
  config : @core.OptimizationConfig,
) -> Result[@core.OptimizationSummary, Array[@core.ValidationError]] {
  let errors = @core.validate_inputs(stock, demands, config)
  if errors.length() > 0 {
    Err(errors)
  } else {
    Ok(solve_best_fit_decreasing_unchecked(stock, demands, config))
  }
}

///|
/// 兼容入口：合法输入正常返回；非法输入立即终止，避免静默产生错误结果。
pub fn solve_first_fit_decreasing(
  stock : @core.StockMaterial,
  demands : Array[@core.DemandItem],
  config : @core.OptimizationConfig,
) -> @core.OptimizationSummary {
  match try_solve_first_fit_decreasing(stock, demands, config) {
    Ok(summary) => summary
    Err(_) =>
      abort(
        "invalid cutting-stock input; use try_solve_first_fit_decreasing for details",
      )
  }
}

///|
/// 兼容入口：合法输入正常返回；非法输入立即终止，避免静默产生错误结果。
pub fn solve_best_fit_decreasing(
  stock : @core.StockMaterial,
  demands : Array[@core.DemandItem],
  config : @core.OptimizationConfig,
) -> @core.OptimizationSummary {
  match try_solve_best_fit_decreasing(stock, demands, config) {
    Ok(summary) => summary
    Err(_) =>
      abort(
        "invalid cutting-stock input; use try_solve_best_fit_decreasing for details",
      )
  }
}

///|
/// 一维套裁问题的带校验综合求解入口。
///
/// 运行 FFD 与 BFD 双策略进行启发式近似竞优。启发式结果不等同于
/// 全局最优解；调用方可以通过 Err 获取输入边界错误，而不是得到静默的空结果。
pub fn try_optimize_cutting_stock(
  stock : @core.StockMaterial,
  demands : Array[@core.DemandItem],
  config : @core.OptimizationConfig,
) -> Result[@core.OptimizationSummary, Array[@core.ValidationError]] {
  let errors = @core.validate_inputs(stock, demands, config)
  if errors.length() > 0 {
    return Err(errors)
  }
  let ffd = solve_first_fit_decreasing_unchecked(stock, demands, config)
  let bfd = solve_best_fit_decreasing_unchecked(stock, demands, config)

  if bfd.total_stocks_used < ffd.total_stocks_used {
    Ok(bfd)
  } else if bfd.total_stocks_used > ffd.total_stocks_used {
    Ok(ffd)
  } else if bfd.total_scrap_length_mm <= ffd.total_scrap_length_mm {
    Ok(bfd)
  } else {
    Ok(ffd)
  }
}

///|
/// 兼容入口：合法输入正常返回；非法输入立即终止，避免静默产生错误结果。
pub fn optimize_cutting_stock(
  stock : @core.StockMaterial,
  demands : Array[@core.DemandItem],
  config : @core.OptimizationConfig,
) -> @core.OptimizationSummary {
  match try_optimize_cutting_stock(stock, demands, config) {
    Ok(summary) => summary
    Err(_) =>
      abort(
        "invalid cutting-stock input; use try_optimize_cutting_stock for details",
      )
  }
}
