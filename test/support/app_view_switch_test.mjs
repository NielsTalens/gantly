import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

class FakeClassList {
  constructor(initial = []) {
    this.values = new Set(initial);
  }

  add(...tokens) {
    tokens.forEach((token) => this.values.add(token));
  }

  remove(...tokens) {
    tokens.forEach((token) => this.values.delete(token));
  }

  contains(token) {
    return this.values.has(token);
  }

  toggle(token, force) {
    if (force === true) {
      this.values.add(token);
      return true;
    }
    if (force === false) {
      this.values.delete(token);
      return false;
    }
    if (this.values.has(token)) {
      this.values.delete(token);
      return false;
    }
    this.values.add(token);
    return true;
  }
}

class FakeElement {
  constructor({ id = "", dataset = {}, classes = [], textContent = "" } = {}) {
    this.id = id;
    this.dataset = dataset;
    this.classList = new FakeClassList(classes);
    this.textContent = textContent;
    this.value = textContent;
    this.innerHTML = "";
    this.disabled = false;
    this.listeners = new Map();
    this.children = [];
    this.queryMap = new Map();
    this.queryAllMap = new Map();
  }

  addEventListener(type, listener) {
    const listeners = this.listeners.get(type) || [];
    listeners.push(listener);
    this.listeners.set(type, listeners);
  }

  async click() {
    const listeners = this.listeners.get("click") || [];
    for (const listener of listeners) {
      await listener();
    }
  }

  appendChild(child) {
    this.children.push(child);
    return child;
  }

  querySelector(selector) {
    return this.queryMap.get(selector) || null;
  }

  querySelectorAll(selector) {
    return this.queryAllMap.get(selector) || [];
  }
}

const featureTab = new FakeElement({
  classes: ["view-tab", "view-tab-feature", "active"],
  dataset: { view: "feature" }
});
const coherenceTab = new FakeElement({
  classes: ["view-tab", "view-tab-coherence"],
  dataset: { view: "coherence" }
});
const projectTag = new FakeElement({
  classes: ["project-tag", "active"],
  dataset: { project: "crm" }
});

const featureInputPanel = new FakeElement({ dataset: { viewPanel: "feature" } });
const coherenceInputPanel = new FakeElement({
  dataset: { viewPanel: "coherence" },
  classes: ["hidden"]
});
const featureSummaryPanel = new FakeElement({
  dataset: { viewPanel: "feature" },
  classes: ["summary"]
});
const coherenceSummaryPanel = new FakeElement({
  dataset: { viewPanel: "coherence" },
  classes: ["summary", "hidden"]
});
const featureCardsPanel = new FakeElement({
  id: "cards",
  dataset: { viewPanel: "feature" }
});
featureCardsPanel.innerHTML = "<div>old feature result</div>";
const coherenceCardsPanel = new FakeElement({
  id: "coherence-cards",
  dataset: { viewPanel: "coherence" },
  classes: ["hidden"]
});
coherenceCardsPanel.innerHTML = "<div>old coherence result</div>";

const elementsById = new Map([
  ["evaluate", new FakeElement({ id: "evaluate" })],
  ["run-coherence", new FakeElement({ id: "run-coherence" })],
  ["loading", new FakeElement({ id: "loading", classes: ["hidden"] })],
  ["coherence-loading", new FakeElement({ id: "coherence-loading", classes: ["hidden"] })],
  ["summary", new FakeElement({ id: "summary", textContent: "Completed 5/5 evaluator runs (0 failed)." })],
  ["coherence-summary", new FakeElement({ id: "coherence-summary", textContent: "No alignment guard run yet." })],
  ["cards", featureCardsPanel],
  ["coherence-cards", coherenceCardsPanel],
  ["feature-input", new FakeElement({ id: "feature-input", textContent: "Old feature" })]
]);

const projectTagsContainer = new FakeElement();
projectTagsContainer.queryAllMap.set(".project-tag", [projectTag]);

const viewTabsContainer = new FakeElement();
viewTabsContainer.queryAllMap.set(".view-tab", [featureTab, coherenceTab]);

const viewPanels = [
  featureInputPanel,
  coherenceInputPanel,
  featureSummaryPanel,
  coherenceSummaryPanel,
  featureCardsPanel,
  coherenceCardsPanel
];

const document = {
  getElementById(id) {
    return elementsById.get(id) || null;
  },
  querySelector(selector) {
    if (selector === "[data-project-tags]") return projectTagsContainer;
    if (selector === "[data-view-tabs]") return viewTabsContainer;
    return null;
  },
  querySelectorAll(selector) {
    if (selector === "[data-view-panel]") return viewPanels;
    return [];
  },
  createElement() {
    return new FakeElement();
  }
};

const fetchCalls = [];
const context = vm.createContext({
  document,
  fetch: async (url) => {
    fetchCalls.push(url);
    if (url === "/evaluate") {
      return {
        ok: true,
        async json() {
          return {
            meta: { total: 1, succeeded: 1, failed: 0 },
            evaluations: [],
            errors: []
          };
        }
      };
    }

    return {
      ok: true,
      async json() {
        return {
          summary: {
            overall_structural_risk: "Low",
            dominant_misalignment_pattern: "none",
            most_leverage_fix: "None"
          },
          pairs: []
        };
      }
    };
  },
  URLSearchParams,
  alert: () => {},
  console
});

const scriptPath = path.resolve("public/app.js");
const script = fs.readFileSync(scriptPath, "utf8");
vm.runInContext(script, context, { filename: scriptPath });

await elementsById.get("run-coherence").click();

assert.deepEqual(fetchCalls, ["/coherence"]);
assert.equal(featureTab.classList.contains("active"), false, "feature tab should no longer be active");
assert.equal(coherenceTab.classList.contains("active"), true, "coherence tab should become active");
assert.equal(featureCardsPanel.classList.contains("hidden"), true, "feature results should be hidden");
assert.equal(coherenceCardsPanel.classList.contains("hidden"), false, "coherence results should be visible");
assert.equal(featureCardsPanel.innerHTML, "", "feature results should be cleared when coherence runs");

await elementsById.get("evaluate").click();

assert.deepEqual(fetchCalls, ["/coherence", "/evaluate"]);
assert.equal(featureTab.classList.contains("active"), true, "feature tab should become active");
assert.equal(coherenceTab.classList.contains("active"), false, "coherence tab should no longer be active");
assert.equal(featureCardsPanel.classList.contains("hidden"), false, "feature results should be visible");
assert.equal(coherenceCardsPanel.classList.contains("hidden"), true, "coherence results should be hidden");
assert.equal(coherenceCardsPanel.innerHTML, "", "coherence results should be cleared when feature evaluation runs");
