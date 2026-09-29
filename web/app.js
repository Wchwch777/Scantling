// Copyright 2026 Scantling Authors
// Licensed under Apache-2.0
//
// Scantling 交互式前端工作台
// 当前页面使用独立 JavaScript 参考引擎，保证 file:// 离线打开即可运行。
// scripts/build_wasm.* 只负责构建可选 Wasm 产物，尚未接入页面运行时。

let defaultDemands = [
  { id: "KZ-01", length: 3800, qty: 8, tag: "柱基础插筋" },
  { id: "KZ-02", length: 2700, qty: 12, tag: "柱主筋" },
  { id: "KL-01", length: 2400, qty: 10, tag: "梁下通长筋" },
  { id: "KL-02", length: 1500, qty: 6, tag: "次梁负筋" }
];

const MAX_PIECES = 2000;
const MAX_DEMAND_ROWS = 200;

function showError(message) {
  const box = document.getElementById("inputError");
  box.textContent = message;
  box.hidden = !message;
}

function readNumber(id, label, { positive = false, integer = false } = {}) {
  const raw = document.getElementById(id).value.trim();
  const value = Number(raw);
  if (raw === "" || !Number.isFinite(value) || (positive ? value <= 0 : value < 0) || (integer && !Number.isSafeInteger(value))) {
    throw new Error(`${label}必须是${positive ? "大于 0" : "非负"}的${integer ? "整数" : "有限数字"}`);
  }
  return value;
}

function renderDemandRows(demands) {
  const tbody = document.querySelector("#demandTable tbody");
  if (!tbody) return;
  tbody.replaceChildren();
  demands.forEach((d, idx) => {
    const tr = document.createElement("tr");
    for (const [field, type, width] of [["id", "text", 80], ["length", "number", 90], ["qty", "number", 60], ["tag", "text", 100]]) {
      const td = document.createElement("td");
      const input = document.createElement("input");
      input.type = type;
      input.value = d[field];
      input.style.width = `${width}px`;
      if (type === "number") input.step = field === "qty" ? "1" : "any";
      input.addEventListener("input", () => updateDemand(idx, field, input.value));
      td.appendChild(input);
      tr.appendChild(td);
    }
    const action = document.createElement("td");
    const remove = document.createElement("button");
    remove.className = "btn btn-sm btn-danger";
    remove.type = "button";
    remove.textContent = "×";
    remove.addEventListener("click", () => removeDemandRow(idx));
    action.appendChild(remove);
    tr.appendChild(action);
    tbody.appendChild(tr);
  });
}

function updateDemand(idx, field, val) {
  defaultDemands[idx][field] = val;
}

function addDemandRow() {
  if (defaultDemands.length >= MAX_DEMAND_ROWS) {
    showError(`最多添加 ${MAX_DEMAND_ROWS} 行需求`);
    return;
  }
  defaultDemands.push({ id: `REQ-${defaultDemands.length + 1}`, length: 2000, qty: 5, tag: "自定构件" });
  renderDemandRows(defaultDemands);
}

function removeDemandRow(idx) {
  defaultDemands.splice(idx, 1);
  renderDemandRows(defaultDemands);
}

function loadPreset() {
  defaultDemands = [
    { id: "KZ-01", length: 3800, qty: 8, tag: "柱基础插筋" },
    { id: "KZ-02", length: 2700, qty: 12, tag: "柱主筋" },
    { id: "KL-01", length: 2400, qty: 10, tag: "梁下通长筋" },
    { id: "KL-02", length: 1500, qty: 6, tag: "次梁负筋" }
  ];
  renderDemandRows(defaultDemands);
  runOptimization();
}

// 启发式套裁计算与工程量清单组价
function runOptimization() {
  let stockLen, unitWeight, matPrice, scrapPrice, kerf, minReusable, demands;
  try {
    stockLen = readNumber("stockLength", "母材定尺", { positive: true });
    unitWeight = readNumber("unitWeight", "线密度", { positive: true });
    matPrice = readNumber("matPrice", "原材单价");
    scrapPrice = readNumber("scrapPrice", "回收单价");
    kerf = readNumber("kerfWidth", "锯口");
    minReusable = readNumber("minReusable", "余料阈值");
    if (defaultDemands.length === 0) throw new Error("请至少添加一行需求");
    demands = defaultDemands.map((d, i) => {
      const length = Number(d.length);
      const qty = Number(d.qty);
      if (String(d.length).trim() === "" || !Number.isFinite(length) || length <= 0 || length > stockLen) {
        throw new Error(`第 ${i + 1} 行切件长度须大于 0 且不超过母材定尺`);
      }
      if (String(d.qty).trim() === "" || !Number.isSafeInteger(qty) || qty <= 0) {
        throw new Error(`第 ${i + 1} 行根数须为正整数`);
      }
      return { id: String(d.id), tag: String(d.tag), length, qty };
    });
    if (demands.reduce((sum, d) => sum + d.qty, 0) > MAX_PIECES) {
      throw new Error(`切件总数不得超过 ${MAX_PIECES}`);
    }
    if (!Number.isFinite(stockLen * unitWeight * matPrice * MAX_PIECES)) {
      throw new Error("输入量级过大，计算可能溢出");
    }
    showError("");
  } catch (error) {
    showError(error.message);
    return;
  }

  // 2. 展平需求件
  let pieces = [];
  demands.forEach(d => {
    for (let i = 0; i < d.qty; i++) {
      pieces.push({ id: d.id, length: d.length, tag: d.tag });
    }
  });

  // 3. 降序排列 (FFD 参考实现)
  pieces.sort((a, b) => b.length - a.length);

  // 4. 套裁匹配
  let bars = [];
  pieces.forEach(p => {
    let placed = false;
    for (let bar of bars) {
      let extraKerf = bar.cuts.length > 0 ? kerf : 0;
      if (bar.used + bar.kerf + p.length + extraKerf <= stockLen) {
        if (bar.cuts.length > 0) bar.kerf += kerf;
        bar.cuts.push(p);
        bar.used += p.length;
        placed = true;
        break;
      }
    }
    if (!placed) {
      bars.push({
        stockLen: stockLen,
        cuts: [p],
        used: p.length,
        kerf: 0
      });
    }
  });

  // 5. 指标统计与造价核算
  let totalStockLength = bars.length * stockLen;
  let totalDemanded = 0;
  let totalKerf = 0;
  let totalReusable = 0;
  let totalScrap = 0;

  bars.forEach(b => {
    totalDemanded += b.used;
    totalKerf += b.kerf;
    let rem = stockLen - b.used - b.kerf;
    b.remnant = rem;
    b.isReusable = rem >= minReusable;
    if (b.isReusable) totalReusable += rem;
    else totalScrap += rem;
  });

  const wasteRatio = totalStockLength > 0 ? (totalKerf + totalScrap) / totalStockLength : 0;
  const reusableRatio = totalStockLength > 0 ? totalReusable / totalStockLength : 0;

  // 参数化造价演示；费率和价格为输入假设，并非地方定额核验。
  const factor = (unitWeight / 1000) / 1000;
  const netWeight = totalDemanded * factor;
  const grossWeight = totalStockLength * factor;
  const grossMatCost = grossWeight * matPrice;
  const scrapWeight = (totalScrap + totalKerf) * factor;
  const scrapRecovery = scrapWeight * scrapPrice;
  const reusableWeight = totalReusable * factor;
  const reusableCredit = reusableWeight * matPrice * 0.85;
  const netMatCost = grossMatCost - scrapRecovery - reusableCredit;

  const laborCost = grossWeight * 650.0;
  const machCost = grossWeight * 180.0;
  const directCost = netMatCost + laborCost + machCost;
  const mgtCost = (laborCost + machCost) * 0.08;
  const profit = (directCost + mgtCost) * 0.05;
  const tax = (directCost + mgtCost + profit) * 0.09;
  const totalCost = directCost + mgtCost + profit + tax;
  const unitPrice = netWeight > 0 ? totalCost / netWeight : 0;
  if (![totalCost, unitPrice, netMatCost, wasteRatio, reusableRatio].every(Number.isFinite)) {
    showError("计算结果超出有限数值范围，请缩小输入");
    return;
  }

  // 更新指标
  document.getElementById("kpiBars").innerText = `${bars.length} 根`;
  document.getElementById("kpiWaste").innerText = `${(wasteRatio * 100).toFixed(2)}%`;
  document.getElementById("kpiReusable").innerText = `${(reusableRatio * 100).toFixed(2)}%`;
  document.getElementById("kpiPrice").innerText = `¥ ${Math.round(unitPrice).toLocaleString()} /t`;

  // 更新造价明细表
  document.getElementById("resNetWeight").innerText = netWeight.toFixed(3);
  document.getElementById("resGrossWeight").innerText = grossWeight.toFixed(3);
  document.getElementById("resGrossMatCost").innerText = `¥ ${grossMatCost.toFixed(2)}`;
  document.getElementById("resScrapRecovery").innerText = `- ¥ ${scrapRecovery.toFixed(2)}`;
  document.getElementById("resReusableCredit").innerText = `- ¥ ${reusableCredit.toFixed(2)}`;
  document.getElementById("resNetMatCost").innerText = `¥ ${netMatCost.toFixed(2)}`;
  document.getElementById("resLaborCost").innerText = `¥ ${laborCost.toFixed(2)}`;
  document.getElementById("resMachCost").innerText = `¥ ${machCost.toFixed(2)}`;
  document.getElementById("resMgtCost").innerText = `¥ ${mgtCost.toFixed(2)}`;
  document.getElementById("resProfit").innerText = `¥ ${profit.toFixed(2)}`;
  document.getElementById("resTax").innerText = `¥ ${tax.toFixed(2)}`;
  document.getElementById("resTotalCost").innerText = `¥ ${totalCost.toFixed(2)}`;

  // 渲染排料图
  const container = document.getElementById("patternsContainer");
  container.replaceChildren();
  bars.forEach((b, i) => {
    const div = document.createElement("div");
    div.className = "pattern-bar";
    const header = document.createElement("div");
    header.className = "pattern-header";
    const name = document.createElement("span");
    name.textContent = `母材 #${i + 1} (${stockLen} mm)`;
    const detail = document.createElement("span");
    detail.textContent = `${b.cuts.length} 个切段 | 剩余: ${Math.round(b.remnant)} mm (${b.isReusable ? "可复用（模型分类）" : "废料残余"})`;
    header.append(name, detail);
    const track = document.createElement("div");
    track.className = "pattern-track";
    b.cuts.forEach(c => {
      const segment = document.createElement("div");
      segment.className = "track-seg seg-cut";
      segment.style.width = `${(c.length / stockLen) * 100}%`;
      segment.title = `${c.id} (${c.length}mm)`;
      segment.textContent = `${c.id} (${c.length})`;
      track.appendChild(segment);
    });
    const rem = document.createElement("div");
    rem.className = `track-seg ${b.isReusable ? "seg-reusable" : "seg-scrap"}`;
    rem.style.width = `${(b.remnant / stockLen) * 100}%`;
    rem.textContent = b.isReusable ? `余料复用: ${Math.round(b.remnant)}mm` : `废料: ${Math.round(b.remnant)}mm`;
    rem.title = rem.textContent;
    track.appendChild(rem);
    div.append(header, track);
    container.appendChild(div);
  });
}

window.onload = function() {
  renderDemandRows(defaultDemands);
  runOptimization();
};
