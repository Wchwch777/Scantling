// Minimal DOM harness for input boundaries and text-only rendering. No browser parity claim.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

class Element {
  constructor() {
    this.children = [];
    this.style = {};
    this.value = "";
    this.textContent = "";
    this.hidden = false;
  }
  set innerHTML(_) { throw new Error("HTML injection sink used"); }
  appendChild(child) { this.children.push(child); }
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children = children; }
  addEventListener() {}
  set innerText(value) { this.textContent = value; }
}

const ids = new Map();
for (const [id, value] of Object.entries({
  stockLength: "9000", unitWeight: "3.85", matPrice: "3850",
  scrapPrice: "2300", kerfWidth: "3", minReusable: "800"
})) ids.set(id, Object.assign(new Element(), { value }));
for (const id of ["inputError", "patternsContainer", "kpiBars", "kpiWaste", "kpiReusable", "kpiPrice",
  "resNetWeight", "resGrossWeight", "resGrossMatCost", "resScrapRecovery", "resReusableCredit",
  "resNetMatCost", "resLaborCost", "resMachCost", "resMgtCost", "resProfit", "resTax", "resTotalCost"])
  ids.set(id, new Element());
const tbody = new Element();
const document = {
  getElementById: id => ids.get(id),
  querySelector: selector => selector === "#demandTable tbody" ? tbody : null,
  createElement: () => new Element()
};
const context = vm.createContext({ document, window: {}, Number, Math, String });
vm.runInContext(fs.readFileSync(require("node:path").join(__dirname, "app.js"), "utf8"), context);
const run = code => vm.runInContext(code, context);
run("window.onload()");
assert.equal(ids.get("kpiBars").textContent, "12 根");
assert.equal(ids.get("inputError").hidden, true);

ids.get("stockLength").value = "";
run("runOptimization()");
assert.match(ids.get("inputError").textContent, /母材定尺/);
ids.get("stockLength").value = "9000";
ids.get("matPrice").value = "-1";
run("runOptimization()");
assert.match(ids.get("inputError").textContent, /原材单价/);
ids.get("matPrice").value = "Infinity";
run("runOptimization()");
assert.match(ids.get("inputError").textContent, /原材单价/);
ids.get("matPrice").value = "3850";
ids.get("kerfWidth").value = "0";
run("updateDemand(0, 'qty', '0'); runOptimization()");
assert.match(ids.get("inputError").textContent, /根数/);
run("updateDemand(0, 'qty', '8'); updateDemand(0, 'id', '<img src=x onerror=alert(1)>'); renderDemandRows(defaultDemands); runOptimization()");
assert.equal(tbody.children[0].children[0].children[0].value, "<img src=x onerror=alert(1)>");
assert.match(ids.get("patternsContainer").children[0].children[1].children[0].textContent, /<img src=x/);
assert.equal(ids.get("inputError").hidden, true);
run("updateDemand(0, 'qty', '2001'); runOptimization()");
assert.match(ids.get("inputError").textContent, /切件总数/);
console.log("Web input and safe-render checks passed");
