# Scantling 工程造价与套裁优化数学模型规范 (Specifications)

## 1. 行业背景与问题定义

本仓库研究给定母材、切件需求和锯口参数时的一维排料，并用可配置价格、费率及余料折价假设计算成本。仓库没有工程现场样本或地方定额数据；这里的数值均为模型输入或演示输出。

MoonBit 实现 FFD/BFD 启发式及参数化计价公式。本文描述当前代码的数学口径，不构成 GB 50500 合规性结论。

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

代码在 FFD/BFD 两个候选结果之间，先比较母材根数，再比较不可复用残料长度。该选择规则可以写成候选集合上的字典序最小化：
$$\min_{s \in \{\mathrm{FFD},\mathrm{BFD}\}} \left(N_s,\sum_{j=1}^{N_s}\mathbb{I}(R_j < L_{\text{reusable\_min}})R_j\right)$$
它既不搜索所有可行排料，也不以锯口总量作为同根数时的独立择优项。

---

## 3. 参数化综合单价模型

以下公式对应当前 `pricing` 实现。默认费率、单价与损耗率是示例参数；当地定额、税务处理、合同口径和审计正确性需要独立核验。

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
