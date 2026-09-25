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

function renderDemandRows(demands) {
  const tbody = document.querySelector("#demandTable tbody");
  if (!tbody) return;
  tbody.innerHTML = "";
  demands.forEach((d, idx) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><input type="text" value="${d.id}" style="width: 80px;" onchange="updateDemand(${idx}, 'id', this.value)"></td>
      <td><input type="number" value="${d.length}" style="width: 90px;" onchange="updateDemand(${idx}, 'length', parseFloat(this.value))"></td>
      <td><input type="number" value="${d.qty}" style="width: 60px;" onchange="updateDemand(${idx}, 'qty', parseInt(this.value))"></td>
      <td><input type="text" value="${d.tag}" style="width: 100px;" onchange="updateDemand(${idx}, 'tag', this.value)"></td>
      <td><button class="btn btn-sm btn-danger" onclick="removeDemandRow(${idx})">×</button></td>
    `;
    tbody.appendChild(tr);
  });
}

function updateDemand(idx, field, val) {
  defaultDemands[idx][field] = val;
}

function addDemandRow() {
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
  const stockLen = parseFloat(document.getElementById("stockLength").value) || 9000;
  const unitWeight = parseFloat(document.getElementById("unitWeight").value) || 3.85;
  const matPrice = parseFloat(document.getElementById("matPrice").value) || 3850;
  const scrapPrice = parseFloat(document.getElementById("scrapPrice").value) || 2300;
  const kerf = parseFloat(document.getElementById("kerfWidth").value) || 3;
  const minReusable = parseFloat(document.getElementById("minReusable").value) || 800;

  // 1. 业务边界校验
  if (stockLen <= 0) {
    alert("错误：母材定尺长度必须大于 0！");
    return;
  }
  for (let d of defaultDemands) {
    if (d.length > stockLen) {
      alert(`校验警告：构件 [${d.id}] 定尺 (${d.length}mm) 超过母材定尺 (${stockLen}mm)，无法单根截断！`);
      return;
    }
  }

  // 2. 展平需求件
  let pieces = [];
  defaultDemands.forEach(d => {
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
  container.innerHTML = "";
  bars.forEach((b, i) => {
    const div = document.createElement("div");
    div.className = "pattern-bar";

    let trackHtml = `<div class="pattern-track">`;
    b.cuts.forEach(c => {
      let pct = (c.length / stockLen) * 100;
      trackHtml += `<div class="track-seg seg-cut" style="width: ${pct}%;" title="${c.id} (${c.length}mm)">${c.id} (${c.length})</div>`;
    });
    let remPct = (b.remnant / stockLen) * 100;
    let segClass = b.isReusable ? "seg-reusable" : "seg-scrap";
    let remText = b.isReusable ? `余料复用: ${Math.round(b.remnant)}mm` : `废料: ${Math.round(b.remnant)}mm`;
    trackHtml += `<div class="track-seg ${segClass}" style="width: ${remPct}%;" title="${remText}">${remText}</div>`;
    trackHtml += `</div>`;

    div.innerHTML = `
      <div class="pattern-header">
        <span><strong>母材 #${i + 1}</strong> (${stockLen} mm)</span>
        <span>${b.cuts.length} 个切段 | 剩余: ${Math.round(b.remnant)} mm (${b.isReusable ? '<span style="color:var(--green)">可复用（模型分类）</span>' : '<span style="color:var(--rose)">废料残渣</span>'})</span>
      </div>
      ${trackHtml}
    `;
    container.appendChild(div);
  });
}

window.onload = function() {
  renderDemandRows(defaultDemands);
  runOptimization();
};
