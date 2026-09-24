// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0
//
// Scantling 命令行交互分析控制台与排料图谱输出

///|
fn print_separator() -> Unit {
  println(
    "================================================================================",
  )
}

///|
fn print_subseparator() -> Unit {
  println(
    "--------------------------------------------------------------------------------",
  )
}

///|
fn main {
  print_separator()
  println("  ____                  _   _ _             ")
  println(" / ___|  ___ __ _ _ __ | |_| (_)_ __   __ _ ")
  println(" \\___ \\ / __/ _` | '_ \\| __| | | '_ \\ / _` |")
  println("  ___) | (_| (_| | | | | |_| | | | | | (_| |")
  println(" |____/ \\___\\__,_|_| |_|\\__|_|_|_| |_|\\__, |")
  println("                                      |___/ ")
  println("  Scantling: Construction Cutting-Stock & Cost Quota Engine")
  println(
    "  建筑工程型材套裁优化与综合单价清单测算控制台",
  )
  print_separator()

  // 1. 工程基础输入数据设定
  // 模拟工程：某商业综合体地下室基础底板与框架柱 (KZ1~KZ4) 螺纹钢下料
  let stock = @core.StockMaterial::new(
    "HRB400E-D25", "三级抗震热轧带肋螺纹钢 Φ25", 9000.0, // 9米标准定尺
     3.85, // 理论重量 3.85 kg/m
     3850.0, // 原材市场采购单价 3850 元/t
  )

  let cfg = @core.OptimizationConfig::new(3.0, 800.0) // 3mm 锯口，800mm 以上余料计为入库复用

  let demands = [
    @core.DemandItem::new("KZ-01", 3800.0, 8, "框架柱基础插筋"),
    @core.DemandItem::new("KZ-02", 2700.0, 12, "框架柱二层主筋"),
    @core.DemandItem::new("KL-01", 2400.0, 10, "框架梁跨中下部通长筋"),
    @core.DemandItem::new("KL-02", 1500.0, 6, "次梁支座负弯矩加强筋"),
  ]

  println("[1/3] 读取工程量需求清单与原材规格:")
  println("  原材型号: " + stock.name + " (" + stock.id + ")")
  println(
    "  定尺长度: 9000.0 mm | 理论米重: 3.85 kg/m | 采购基准价: 3850.0 元/t",
  )
  println(
    "  工艺参数: 锯口损耗宽度 = 3.0 mm | 二次利用余料阈值 = 800.0 mm",
  )
  println("  待切割清单项:")
  for d in demands {
    println(
      "    * 构件 [" +
      d.id +
      "] " +
      d.tag +
      ": 长度 " +
      d.length_mm.to_string() +
      " mm, 需求 " +
      d.quantity.to_string() +
      " 根",
    )
  }
  print_subseparator()

  // 2. 启发式套裁优化计算
  println(
    "[2/3] 执行启发式下料排料优化演算 (FFD & Best-Fit 竞优)...",
  )
  let summary = match
    @optimizer.try_optimize_cutting_stock(stock, demands, cfg) {
    Ok(value) => value
    Err(_) =>
      abort(
        "工程输入校验失败：请检查母材定尺、构件长度、需求数量和锯口参数",
      )
  }

  println("  优化完成! 演算结果概要:")
  println(
    "    投入母材总根数: " +
    summary.total_stocks_used.to_string() +
    " 根 (总长: " +
    summary.total_stock_length_mm.to_string() +
    " mm)",
  )
  println(
    "    构件设计净长度: " +
    summary.total_demanded_length_mm.to_string() +
    " mm",
  )
  println(
    "    锯口切削损耗:   " +
    summary.total_kerf_loss_mm.to_string() +
    " mm",
  )
  println(
    "    可回用余料总长: " +
    summary.total_reusable_length_mm.to_string() +
    " mm",
  )
  println(
    "    废钢残渣总长:   " +
    summary.total_scrap_length_mm.to_string() +
    " mm",
  )
  println(
    "    综合材料损耗率: " +
    (summary.waste_ratio * 100.0).to_string() +
    " %",
  )
  println(
    "    余料二次回用率: " +
    (summary.reusable_ratio * 100.0).to_string() +
    " %",
  )
  print_subseparator()

  // 3. 输出下料版样可视化
  println("  排料版样明细 (Cutting Patterns Visualizer):")
  for i = 0; i < summary.patterns.length(); i = i + 1 {
    let p = summary.patterns[i]
    let rem_status = if p.is_reusable { "可复用入库" } else { "废料" }
    println("  母材 #" + (i + 1).to_string() + ":")
    let mut pattern_str = "    ["
    for j = 0; j < p.cuts.length(); j = j + 1 {
      let c = p.cuts[j]
      pattern_str = pattern_str +
        c.demand_id +
        ":" +
        c.length_mm.to_string() +
        "mm"
      if j < p.cuts.length() - 1 {
        pattern_str = pattern_str + " | "
      }
    }
    pattern_str = pattern_str +
      "] -> 余料: " +
      p.remnant_length_mm.to_string() +
      " mm (" +
      rem_status +
      ")"
    println(pattern_str)
  }
  print_subseparator()

  // 4. 清单综合单价与工程全要素造价核算
  println(
    "[3/3] 正在挂接定额基价标准，测算工程全要素造价清单...",
  )
  let quota = @pricing.QuotaStandard::default_rebar()
  let scrap_mkt = @pricing.ScrapMarketParam::default()
  let cost = @pricing.evaluate_cost(stock, summary, quota, scrap_mkt)

  println("  全要素造价明细表 (依据 GB 50500 现行计价标准):")
  println(
    "    - 清单设计净用量:       " +
    cost.net_demanded_weight_ton.to_string() +
    " 吨",
  )
  println(
    "    - 采购下料总毛重:       " +
    cost.gross_procured_weight_ton.to_string() +
    " 吨",
  )
  println(
    "    - 原材采购总投入:       " +
    cost.material_gross_cost.to_string() +
    " 元",
  )
  println(
    "    - 冲减: 废料残渣回收款: -" +
    cost.scrap_recovery_income.to_string() +
    " 元",
  )
  println(
    "    - 冲减: 余料结存折价:   -" +
    cost.reusable_inventory_credit.to_string() +
    " 元",
  )
  println(
    "    - 材料净成本:           " +
    cost.net_material_cost.to_string() +
    " 元",
  )
  println(
    "    - 人工费 (定额安装):    " + cost.labor_cost.to_string() + " 元",
  )
  println(
    "    - 施工机具使用费:       " +
    cost.machinery_cost.to_string() +
    " 元",
  )
  println(
    "    - 企业管理费 (8%):      " +
    cost.management_fee.to_string() +
    " 元",
  )
  println(
    "    - 预期企业利润 (5%):    " + cost.profit.to_string() + " 元",
  )
  println(
    "    - 建筑业增值税 (9%):    " + cost.tax_amount.to_string() + " 元",
  )
  print_subseparator()
  println(
    "  ★ 综合工程总造价 (含税): " +
    cost.total_project_cost.to_string() +
    " 元",
  )
  println(
    "  ★ 清单综合单价 (净用量): " +
    cost.comprehensive_unit_price.to_string() +
    " 元/吨",
  )
  println(
    "  ★ 定额常规基准造价:     " +
    cost.quota_baseline_cost.to_string() +
    " 元",
  )
  println(
    "  ★ 与定额基线成本差额:     " +
    cost.cost_saved_amount.to_string() +
    " 元",
  )
  print_separator()
  println("Scantling 演算完毕，系统运行正常。")
}
