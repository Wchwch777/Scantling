# Scantling 工程造价与套裁优化数学模型规范 (Specifications)

## 1. 行业背景与问题定义

在土木与建筑工程造价管理中，钢筋工程（Rebar Works）与钢结构型材（Steel Profiles）约占土建工程直接造价的 **30% ~ 40%**。传统工地通常依靠施工员经验凭感觉估算下料，导致如下痛点：
1. **损耗超标**：国家规范 GB 50500 允许的定额损耗通常为 $2.0\% \sim 3.0\%$，但在复杂异型构件中，随意截断往往造成 $5\% \sim 8\%$ 以上的无谓废料。
2. **零碎短料无法复用**：没有建立可复用余料库与废料残渣的价值核算通道，造成直接经济损失。
3. **量价脱节**：工程量计算（Takeoff）与造价定额组价（Quota Pricing）割裂，难以快速评估工艺优化带来的实际财务收益。

**Scantling**（源自经典工料测量中“规方定尺”之意）将 **一维切削套裁优化（1D Cutting Stock Problem, CSP）** 与 **建设工程工程量清单计价规范（GB 50500）** 深度整合，基于高性能 MoonBit 语言构建了端到端微内核。

---

## 2. 一维套裁下料数学模型 (1D Cutting Stock with Kerf)

### 2.1 符号系统 (Notations)

* $L_{\text{stock}}$：母材原材定尺长度（如标准 9,000 mm 或 12,000 mm）。
* $D = \{(l_i, q_i) \mid i = 1, \dots, m\}$：下料需求集，其中 $l_i$ 为构件定尺长度，$q_i$ 为需求根数。
* $w_k$：机械锯口截断损耗宽度（Kerf Width，通常为 $3.0 \sim 5.0\text{ mm}$）。
* $L_{\text{reusable\_min}}$：余料二次复用最小有效长度阈值（如 $800\text{ mm}$）。

### 2.2 约束条件

对任意一根母材 $j$，所排布的 $k$ 个切件 $c_{j,1}, c_{j,2}, \dots, c_{j,k}$ 满足物理长度约束：
$$\sum_{r=1}^{k} c_{j,r} + \max(0, k - 1) \cdot w_k \le L_{\text{stock}}$$

其剩余长度（Remnant）定义为：
$$R_j = L_{\text{stock}} - \left( \sum_{r=1}^{k} c_{j,r} + \max(0, k - 1) \cdot w_k \right)$$

分类规则：
$$
\begin{cases}
R_j \in \text{Reusable (可复用余料)}, & \text{if } R_j \ge L_{\text{reusable\_min}} \\
R_j \in \text{Scrap (废钢残渣)}, & \text{if } R_j < L_{\text{reusable\_min}}
\end{cases}
$$

### 2.3 目标函数

优化目标优先极小化投入母材总根数 $N$，在根数相等的前提下极小化废料残渣损失总长：
$$\min \left( N, \sum_{j=1}^N \left( \max(0, k_j - 1) \cdot w_k + \mathbb{I}(R_j < L_{\text{reusable\_min}}) \cdot R_j \right) \right)$$

---

## 3. 全要素综合单价定额模型 (GB 50500)

Scantling 遵循建设工程工程量清单全费用单价与工料机直接费推算标准：

1. **工程量折算（吨位）**：
   $$W_{\text{net}} = \frac{\sum l_i q_i}{10^6} \times \rho_{\text{unit}}, \quad W_{\text{gross}} = \frac{N \cdot L_{\text{stock}}}{10^6} \times \rho_{\text{unit}}$$
2. **净材料费（冲减废料收益与余料库存估值）**：
   $$C_{\text{mat\_net}} = W_{\text{gross}} \cdot P_{\text{stock}} - W_{\text{scrap}} \cdot P_{\text{scrap}} - W_{\text{reusable}} \cdot P_{\text{stock}} \cdot \alpha_{\text{credit}}$$
3. **直接工程费**：
   $$C_{\text{direct}} = C_{\text{mat\_net}} + W_{\text{gross}} \cdot (U_{\text{labor}} + U_{\text{mach}})$$
4. **企业管理费与利润**：
   $$C_{\text{mgt}} = W_{\text{gross}} \cdot (U_{\text{labor}} + U_{\text{mach}}) \cdot r_{\text{mgt}}$$
   $$C_{\text{profit}} = (C_{\text{direct}} + C_{\text{mgt}}) \cdot r_{\text{profit}}$$
5. **建筑业增值税与含税总造价**：
   $$C_{\text{total}} = (C_{\text{direct}} + C_{\text{mgt}} + C_{\text{profit}}) \cdot (1 + r_{\text{tax}})$$
6. **清单综合单价 (Comprehensive Unit Price)**：
   $$P_{\text{comp}} = \frac{C_{\text{total}}}{W_{\text{net}}} \quad (\text{元/吨})$$
