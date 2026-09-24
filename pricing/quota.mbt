// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0
//
// 建筑工程全要素清单计价与工料机定额演算引擎

///|
/// 清单定额基价与取费费率标准 (符合现行建设工程工程量清单计价规范)
pub struct QuotaStandard {
  item_code : String // 清单项目编码 (如 "010515001001")
  item_name : String // 项目名称 (如 "现浇构件螺纹钢筋制作与绑扎")
  labor_unit_cost : Double // 人工费综合基价 (元/t)
  machinery_unit_cost : Double // 施工机具使用费综合基价 (元/t)
  standard_loss_rate : Double // 国家定额标准允许损耗率 (如 0.025 代表 2.5%)
  management_rate : Double // 企业管理费费率 (如 0.08 代表 8%)
  profit_rate : Double // 利润率 (如 0.05 代表 5%)
  tax_rate : Double // 建筑业增值税率 (如 0.09 代表 9%)
} derive(Debug, Eq)

///|
pub fn QuotaStandard::default_rebar() -> QuotaStandard {
  {
    item_code: "010515001001",
    item_name: "现浇构件螺纹钢制作绑扎",
    labor_unit_cost: 650.0,
    machinery_unit_cost: 180.0,
    standard_loss_rate: 0.025,
    management_rate: 0.08,
    profit_rate: 0.05,
    tax_rate: 0.09,
  }
}

///|
pub fn QuotaStandard::new(
  item_code : String,
  item_name : String,
  labor_unit_cost : Double,
  machinery_unit_cost : Double,
  standard_loss_rate : Double,
  management_rate : Double,
  profit_rate : Double,
  tax_rate : Double,
) -> QuotaStandard {
  {
    item_code,
    item_name,
    labor_unit_cost,
    machinery_unit_cost,
    standard_loss_rate,
    management_rate,
    profit_rate,
    tax_rate,
  }
}

///|
/// 残值回收与下料余料结存评估参数
pub struct ScrapMarketParam {
  scrap_price_per_ton : Double // 废钢残渣回收变现单价 (元/t)
  reusable_credit_ratio : Double // 可回用短料折旧冲抵率 (进入次级构件库)
} derive(Debug, Eq)

///|
pub fn ScrapMarketParam::default() -> ScrapMarketParam {
  { scrap_price_per_ton: 2300.0, reusable_credit_ratio: 0.85, }
}

///|
pub fn ScrapMarketParam::new(
  scrap_price_per_ton : Double,
  reusable_credit_ratio : Double,
) -> ScrapMarketParam {
  { scrap_price_per_ton, reusable_credit_ratio, }
}

///|
/// 工程造价全要素明细核算单
pub struct CostBreakdown {
  net_demanded_weight_ton : Double // 清单设计净用量 (t)
  gross_procured_weight_ton : Double // 采购下料总毛重 (t)
  actual_waste_ratio : Double // 实际切削与废料损耗率
  material_gross_cost : Double // 原材采购金额 (元)
  scrap_recovery_income : Double // 废料残值回收冲减金额 (元)
  reusable_inventory_credit : Double // 可用余料结存入库折价 (元)
  net_material_cost : Double // 冲减后材料净成本 (元)
  labor_cost : Double // 定额人工费 (元)
  machinery_cost : Double // 定额机械台班费 (元)
  subtotal_direct_cost : Double // 直接工程费小计 (元)
  management_fee : Double // 企业管理费 (元)
  profit : Double // 企业利润 (元)
  tax_amount : Double // 建筑业增值税金 (元)
  total_project_cost : Double // 综合工程总造价 (含税, 元)
  comprehensive_unit_price : Double // 清单综合单价 (元/t 净重)
  quota_baseline_cost : Double // 行业定额常规造价基线 (元)
  cost_saved_amount : Double // 与当前参数化定额基线的成本差额，正值才表示节约 (元)
} derive(Debug, Eq)

///|
/// 核心测算逻辑：将型材套裁方案映射为严格的工程造价工料机清单明细
pub fn evaluate_cost(
  stock : @core.StockMaterial,
  summary : @core.OptimizationSummary,
  quota : QuotaStandard,
  scrap_market : ScrapMarketParam,
) -> CostBreakdown {
  // 1. 工程量折算为吨位 (长度 mm -> m, unit_weight kg/m -> ton)
  let mm_to_ton_factor = stock.unit_weight_kg_m / 1000.0 / 1000.0
  let net_demanded_weight_ton = summary.total_demanded_length_mm *
    mm_to_ton_factor
  let gross_procured_weight_ton = summary.total_stock_length_mm *
    mm_to_ton_factor

  let scrap_weight_ton = (
      summary.total_scrap_length_mm + summary.total_kerf_loss_mm
    ) *
    mm_to_ton_factor
  let reusable_weight_ton = summary.total_reusable_length_mm * mm_to_ton_factor

  // 2. 材料采购及冲减回收核算
  let material_gross_cost = gross_procured_weight_ton * stock.cost_per_ton
  let scrap_recovery_income = scrap_weight_ton *
    scrap_market.scrap_price_per_ton
  let reusable_inventory_credit = reusable_weight_ton *
    stock.cost_per_ton *
    scrap_market.reusable_credit_ratio
  let net_material_cost = material_gross_cost -
    scrap_recovery_income -
    reusable_inventory_credit

  // 3. 工料机直接费 (人工 + 机械)
  let labor_cost = gross_procured_weight_ton * quota.labor_unit_cost
  let machinery_cost = gross_procured_weight_ton * quota.machinery_unit_cost
  let subtotal_direct_cost = net_material_cost + labor_cost + machinery_cost

  // 4. 企业管理费与利润
  let management_fee = (labor_cost + machinery_cost) * quota.management_rate
  let profit = (subtotal_direct_cost + management_fee) * quota.profit_rate

  // 5. 建筑业增值税
  let pre_tax_amount = subtotal_direct_cost + management_fee + profit
  let tax_amount = pre_tax_amount * quota.tax_rate
  let total_project_cost = pre_tax_amount + tax_amount

  // 6. 清单综合单价 (元/t 净重)
  let comprehensive_unit_price = if net_demanded_weight_ton > 0.0 {
    total_project_cost / net_demanded_weight_ton
  } else {
    0.0
  }

  // 7. 定额常规基线造价对比 (按行业定额允许损耗率进行采购测算)
  let baseline_weight_ton = net_demanded_weight_ton *
    (1.0 + quota.standard_loss_rate)
  let baseline_mat_cost = baseline_weight_ton * stock.cost_per_ton
  let baseline_direct = baseline_mat_cost +
    baseline_weight_ton * (quota.labor_unit_cost + quota.machinery_unit_cost)
  let baseline_mgt = baseline_weight_ton *
    (quota.labor_unit_cost + quota.machinery_unit_cost) *
    quota.management_rate
  let baseline_profit = (baseline_direct + baseline_mgt) * quota.profit_rate
  let baseline_pre_tax = baseline_direct + baseline_mgt + baseline_profit
  let quota_baseline_cost = baseline_pre_tax * (1.0 + quota.tax_rate)

  let cost_saved_amount = quota_baseline_cost - total_project_cost

  {
    net_demanded_weight_ton,
    gross_procured_weight_ton,
    actual_waste_ratio: summary.waste_ratio,
    material_gross_cost,
    scrap_recovery_income,
    reusable_inventory_credit,
    net_material_cost,
    labor_cost,
    machinery_cost,
    subtotal_direct_cost,
    management_fee,
    profit,
    tax_amount,
    total_project_cost,
    comprehensive_unit_price,
    quota_baseline_cost,
    cost_saved_amount,
  }
}
