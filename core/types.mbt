// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0
//
// 建筑工程造价与型材套裁领域核心数据模型

///|
/// 原材型材定义（如标准定尺 9m/12m 螺纹钢、型钢）
pub struct StockMaterial {
  id : String
  name : String
  length_mm : Double
  unit_weight_kg_m : Double
  cost_per_ton : Double
} derive(Debug, Eq)

///|
pub fn StockMaterial::new(
  id : String,
  name : String,
  length_mm : Double,
  unit_weight_kg_m : Double,
  cost_per_ton : Double,
) -> StockMaterial {
  { id, name, length_mm, unit_weight_kg_m, cost_per_ton, }
}

///|
/// 工程量下料需求项（清单定尺切断需求）
pub struct DemandItem {
  id : String
  length_mm : Double
  quantity : Int
  tag : String
} derive(Debug, Eq)

///|
pub fn DemandItem::new(
  id : String,
  length_mm : Double,
  quantity : Int,
  tag : String,
) -> DemandItem {
  { id, length_mm, quantity, tag, }
}

///|
/// 单次切割分件
pub struct CutPiece {
  demand_id : String
  length_mm : Double
} derive(Debug, Eq)

///|
pub fn CutPiece::new(demand_id : String, length_mm : Double) -> CutPiece {
  { demand_id, length_mm, }
}

///|
/// 单根原材的切割方案（版样）
pub struct CutPattern {
  stock_id : String
  stock_length_mm : Double
  cuts : Array[CutPiece]
  used_length_mm : Double
  kerf_loss_mm : Double
  remnant_length_mm : Double
  is_reusable : Bool
} derive(Debug, Eq)

///|
pub fn CutPattern::new(
  stock_id : String,
  stock_length_mm : Double,
  cuts : Array[CutPiece],
  used_length_mm : Double,
  kerf_loss_mm : Double,
  remnant_length_mm : Double,
  is_reusable : Bool,
) -> CutPattern {
  {
    stock_id,
    stock_length_mm,
    cuts,
    used_length_mm,
    kerf_loss_mm,
    remnant_length_mm,
    is_reusable,
  }
}

///|
/// 套裁优化算法配置参数
pub struct OptimizationConfig {
  kerf_width_mm : Double // 锯口切割损耗宽度（通常为 3.0 ~ 5.0 mm）
  min_reusable_length_mm : Double // 最小可复用短料阈值（长于此阈值计为二次利用余料库，短于此计为废钢残渣）
} derive(Debug, Eq)

///|
pub fn OptimizationConfig::default() -> OptimizationConfig {
  { kerf_width_mm: 3.0, min_reusable_length_mm: 800.0, }
}

///|
pub fn OptimizationConfig::new(
  kerf_width_mm : Double,
  min_reusable_length_mm : Double,
) -> OptimizationConfig {
  { kerf_width_mm, min_reusable_length_mm, }
}

///|
/// 套裁结果全景统计指标
pub struct OptimizationSummary {
  total_stocks_used : Int
  total_stock_length_mm : Double
  total_demanded_length_mm : Double
  total_kerf_loss_mm : Double
  total_reusable_length_mm : Double
  total_scrap_length_mm : Double
  waste_ratio : Double // 绝对损耗率 (kerf + scrap) / total_stock
  reusable_ratio : Double // 可回用余料率 reusable / total_stock
  patterns : Array[CutPattern]
} derive(Debug, Eq)

///|
pub fn OptimizationSummary::new(
  total_stocks_used : Int,
  total_stock_length_mm : Double,
  total_demanded_length_mm : Double,
  total_kerf_loss_mm : Double,
  total_reusable_length_mm : Double,
  total_scrap_length_mm : Double,
  waste_ratio : Double,
  reusable_ratio : Double,
  patterns : Array[CutPattern],
) -> OptimizationSummary {
  {
    total_stocks_used,
    total_stock_length_mm,
    total_demanded_length_mm,
    total_kerf_loss_mm,
    total_reusable_length_mm,
    total_scrap_length_mm,
    waste_ratio,
    reusable_ratio,
    patterns,
  }
}

///|
pub fn OptimizationSummary::empty() -> OptimizationSummary {
  {
    total_stocks_used: 0,
    total_stock_length_mm: 0.0,
    total_demanded_length_mm: 0.0,
    total_kerf_loss_mm: 0.0,
    total_reusable_length_mm: 0.0,
    total_scrap_length_mm: 0.0,
    waste_ratio: 0.0,
    reusable_ratio: 0.0,
    patterns: [],
  }
}

///|
/// 下料工程参数边界校验异常
pub(all) enum ValidationError {
  StockLengthNonPositive(Double)
  PieceExceedsStockLength(String, Double, Double)
  QuantityNonPositive(String, Int)
  InvalidKerfWidth(Double)
} derive(Debug, Eq)

///|
/// 校验下料工程量与原材规格参数边界
pub fn validate_inputs(
  stock : StockMaterial,
  demands : Array[DemandItem],
  config : OptimizationConfig,
) -> Array[ValidationError] {
  let errors : Array[ValidationError] = []
  if stock.length_mm <= 0.0 {
    errors.push(ValidationError::StockLengthNonPositive(stock.length_mm))
  }
  if config.kerf_width_mm < 0.0 {
    errors.push(ValidationError::InvalidKerfWidth(config.kerf_width_mm))
  }
  for d in demands {
    if d.quantity <= 0 {
      errors.push(ValidationError::QuantityNonPositive(d.id, d.quantity))
    }
    if stock.length_mm > 0.0 && d.length_mm > stock.length_mm {
      errors.push(
        ValidationError::PieceExceedsStockLength(
          d.id,
          d.length_mm,
          stock.length_mm,
        ),
      )
    }
  }
  errors
}
