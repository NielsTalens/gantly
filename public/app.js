const evaluateButton = document.getElementById("evaluate");
const coherenceButton = document.getElementById("run-coherence");
const loading = document.getElementById("loading");
const coherenceLoading = document.getElementById("coherence-loading");
const tagContainer = document.querySelector("[data-project-tags]");
const projectTags = tagContainer ? Array.from(tagContainer.querySelectorAll(".project-tag")) : [];
const viewTabsContainer = document.querySelector("[data-view-tabs]");
const viewTabs = viewTabsContainer ? Array.from(viewTabsContainer.querySelectorAll(".view-tab")) : [];
const viewPanels = Array.from(document.querySelectorAll("[data-view-panel]"));
const taskTitle = document.getElementById("task-title");
const taskHelp = document.getElementById("task-help");
const summary = document.getElementById("summary");
const coherenceSummary = document.getElementById("coherence-summary");
const featureCards = document.getElementById("cards");
const coherenceCards = document.getElementById("coherence-cards");
let selectedProject = projectTags.find((tag) => tag.classList.contains("active"))?.dataset.project || "";
let activeView = viewTabs.find((tab) => tab.classList.contains("active"))?.dataset.view || "feature";
const defaultFeatureSummary = summary?.textContent || "No evaluation yet.";
const defaultCoherenceSummary = coherenceSummary?.textContent || "No alignment guard run yet.";
const VIEW_CONTENT = {
  feature: {
    taskTitle: "Feature Proposal",
    taskHelp: "Paste a proposed feature and Gantly will score it against the selected product definition."
  },
  coherence: {
    taskTitle: "Fundamentals Alignment",
    taskHelp: "Run a structural coherence check across the selected project's strategy, vision, JTBD, and charter documents."
  }
};
const AGENT_LABELS = {
  strategy: "Strategy",
  vision: "Product Vision",
  jtbd: "Jobs to be done",
  product_charter: "Product Charter",
  feedback: "Feedback"
};

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#39;");
}

function normalizedSeverity(value) {
  const severity = String(value || "Medium");
  if (severity === "Low" || severity === "Medium" || severity === "High") return severity;
  return "Medium";
}

function setActiveView(view) {
  activeView = view;
  const viewContent = VIEW_CONTENT[view] || VIEW_CONTENT.feature;

  viewTabs.forEach((tab) => {
    tab.classList.toggle("active", tab.dataset.view === view);
  });
  viewPanels.forEach((panel) => {
    panel.classList.toggle("hidden", panel.dataset.viewPanel !== view);
  });
  if (taskTitle) taskTitle.textContent = viewContent.taskTitle;
  if (taskHelp) taskHelp.textContent = viewContent.taskHelp;
}

function clearFeatureResults() {
  if (summary) summary.textContent = defaultFeatureSummary;
  if (featureCards) featureCards.innerHTML = "";
}

function clearCoherenceResults() {
  if (coherenceSummary) coherenceSummary.textContent = defaultCoherenceSummary;
  if (coherenceCards) coherenceCards.innerHTML = "";
}

function renderEvaluationDetails(ev) {
  const conflicts = Array.isArray(ev.detected_conflicts) ? ev.detected_conflicts : [];
  const positiveAlignment = Array.isArray(ev.mostly_aligns_with) ? ev.mostly_aligns_with : [];
  const actions = Array.isArray(ev.what_would_make_this_a_5_of_5) ? ev.what_would_make_this_a_5_of_5 : [];

  const primaryInsightsTitle = conflicts.length ? "Detected Conflicts" : "Mostly Aligns With";
  const primaryInsightsHtml = conflicts.length
    ? `<ul class="conflict-list">${conflicts.map((entry) => {
        if (entry && typeof entry === "object") {
          const severity = normalizedSeverity(entry.severity);
          const evidence = Array.isArray(entry.evidence) ? entry.evidence : [];
          return `
            <li class="conflict-item">
              <div class="conflict-header">
                <span>${escapeHtml(entry.conflict || "Conflict not specified.")}</span>
                <span class="severity severity-${severity.toLowerCase()}">${severity}</span>
              </div>
              ${evidence.length ? `<ul class="evidence-list">${evidence.map((line) => `<li>${escapeHtml(line)}</li>`).join("")}</ul>` : ""}
            </li>
          `;
        }
        return `<li class="conflict-item">${escapeHtml(entry)}</li>`;
      }).join("")}</ul>`
    : positiveAlignment.length
    ? `<ul class="action-list">${positiveAlignment.map((line) => `<li>${escapeHtml(line)}</li>`).join("")}</ul>`
    : "<p class=\"empty-copy\">No conflicts detected.</p>";

  const actionsHtml = actions.length
    ? `<ul class="action-list">${actions.map((line) => `<li>${escapeHtml(line)}</li>`).join("")}</ul>`
    : "<p class=\"empty-copy\">No actions provided.</p>";

  return `
    <div class="details-panel hidden">
      <div class="details-grid">
        <div><span class="detail-label">Alignment</span><strong>${escapeHtml(ev.alignment_score)}</strong></div>
        <div><span class="detail-label">Confidence</span><strong>${escapeHtml(ev.confidence_score)}</strong></div>
      <div><span class="detail-label">Risk</span><strong>${escapeHtml(ev.risk_level)}</strong></div>
      </div>
      <section class="details-section">
        <h4>${primaryInsightsTitle}</h4>
        ${primaryInsightsHtml}
      </section>
      <section class="details-section">
        <h4>What Would Make This a 5/5</h4>
        ${actionsHtml}
      </section>
    </div>
    <pre class="raw-json hidden">${escapeHtml(JSON.stringify(ev, null, 2))}</pre>
  `;
}

function renderCoherenceDetails(pair) {
  const themes = Array.isArray(pair.core_alignment_themes) ? pair.core_alignment_themes : [];
  const contradictions = Array.isArray(pair.detected_contradictions) ? pair.detected_contradictions : [];
  const missingLinks = Array.isArray(pair.missing_links) ? pair.missing_links : [];

  const renderList = (items, emptyCopy) =>
    items.length
      ? `<ul class="action-list">${items.map((line) => `<li>${escapeHtml(line)}</li>`).join("")}</ul>`
      : `<p class="empty-copy">${emptyCopy}</p>`;

  return `
    <div class="details-panel hidden">
      <div class="details-grid">
        <div><span class="detail-label">Alignment</span><strong>${escapeHtml(pair.alignment_score)}</strong></div>
        <div><span class="detail-label">Confidence</span><strong>${escapeHtml(pair.confidence_score)}</strong></div>
        <div><span class="detail-label">Risk</span><strong>${escapeHtml(pair.structural_risk_level)}</strong></div>
      </div>
      <section class="details-section">
        <h4>Core Alignment Themes</h4>
        ${renderList(themes, "No strong alignment themes called out.")}
      </section>
      <section class="details-section">
        <h4>Detected Contradictions</h4>
        ${renderList(contradictions, "No contradictions detected.")}
      </section>
      <section class="details-section">
        <h4>Missing Links</h4>
        ${renderList(missingLinks, "No missing links called out.")}
      </section>
      <section class="details-section">
        <h4>Minimal Change to Improve Coherence</h4>
        <p class="empty-copy">${escapeHtml(pair.minimal_change_to_improve_coherence || "No minimal change provided.")}</p>
      </section>
    </div>
    <pre class="raw-json hidden">${escapeHtml(JSON.stringify(pair, null, 2))}</pre>
  `;
}

function renderCoherenceSummary(summary) {
  const crossFindings = summary.cross_document_findings || {};
  const findingGroups = [
    ["Target customer mismatches", crossFindings.target_customer_mismatches || []],
    ["Ambition mismatches", crossFindings.ambition_mismatches || []],
    ["Scope inflation or dilution risks", crossFindings.scope_inflation_or_dilution_risks || []]
  ];

  const findingsHtml = findingGroups.map(([label, items]) => {
    if (!items.length) {
      return `<section class="details-section"><h4>${escapeHtml(label)}</h4><p class="empty-copy">None noted.</p></section>`;
    }
    return `<section class="details-section"><h4>${escapeHtml(label)}</h4><ul class="action-list">${items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul></section>`;
  }).join("");

  return `
    <div><strong>Overall structural risk:</strong> ${escapeHtml(summary.overall_structural_risk || "Medium")}</div>
    <div><strong>Dominant misalignment pattern:</strong> ${escapeHtml(summary.dominant_misalignment_pattern || "Not provided.")}</div>
    <div><strong>Most leverage fix:</strong> ${escapeHtml(summary.most_leverage_fix || "Not provided.")}</div>
    ${findingsHtml}
  `;
}

projectTags.forEach((tag) => {
  tag.addEventListener("click", () => {
    projectTags.forEach((btn) => btn.classList.remove("active"));
    tag.classList.add("active");
    selectedProject = tag.dataset.project || "";
  });
});

function getSelectedProject() {
  const activeTag = projectTags.find((tag) => tag.classList.contains("active"));
  return activeTag?.dataset.project || selectedProject;
}

viewTabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    setActiveView(tab.dataset.view || "feature");
  });
});

if (evaluateButton) {
  evaluateButton.disabled = projectTags.length === 0;
  evaluateButton.addEventListener("click", async () => {
    evaluateButton.disabled = true;
    evaluateButton.textContent = "Evaluating...";
    if (loading) loading.classList.remove("hidden");

    try {
      const project = getSelectedProject();

      if (!project) {
        evaluateButton.disabled = false;
        evaluateButton.textContent = "Evaluate";
        if (loading) loading.classList.add("hidden");
        alert("Select a project first.");
        return;
      }

      clearCoherenceResults();
      setActiveView("feature");

      const feature = document.getElementById("feature-input").value;
      const res = await fetch("/evaluate", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ feature_proposal: feature, project })
      });
      const data = await res.json();
      const meta = data.meta || { total: 0, succeeded: 0, failed: 0 };
      summary.textContent = `Completed ${meta.succeeded}/${meta.total} evaluator runs (${meta.failed} failed).`;

      featureCards.innerHTML = "";
      (data.evaluations || []).forEach((ev) => {
        const card = document.createElement("div");
        card.className = "card";
        const scoreClass = `score-${Math.max(1, Math.min(5, Number(ev.alignment_score) || 1))}`;
        card.innerHTML = `
          <div class="card-header">
            <strong>${AGENT_LABELS[ev.agent] || ev.agent}</strong>
            <span class="score-pill ${scoreClass}">Score: ${ev.alignment_score}</span>
          </div>
          <div class="card-actions">
            <button class="toggle toggle-details">Details</button>
            <button class="toggle toggle-raw">Raw JSON</button>
          </div>
          ${renderEvaluationDetails(ev)}
        `;
        card.querySelector(".toggle-details").addEventListener("click", () => {
          card.querySelector(".details-panel").classList.toggle("hidden");
        });
        card.querySelector(".toggle-raw").addEventListener("click", () => {
          card.querySelector(".raw-json").classList.toggle("hidden");
        });
        featureCards.appendChild(card);
      });

      (data.errors || []).forEach((error) => {
        const card = document.createElement("div");
        card.className = "card";
        card.innerHTML = `
          <div class="card-header">
            <strong>${AGENT_LABELS[error.agent] || error.agent}</strong>
            <span>Error</span>
          </div>
          <pre>${error.message}</pre>
        `;
        featureCards.appendChild(card);
      });
    } finally {
      evaluateButton.disabled = false;
      evaluateButton.textContent = "Evaluate";
      if (loading) loading.classList.add("hidden");
    }
  });
}

if (coherenceButton) {
  coherenceButton.disabled = projectTags.length === 0;
  coherenceButton.addEventListener("click", async () => {
    coherenceButton.disabled = true;
    coherenceButton.textContent = "Running...";
    if (coherenceLoading) coherenceLoading.classList.remove("hidden");

    try {
      const project = getSelectedProject();

      if (!project) {
        coherenceButton.disabled = false;
        coherenceButton.textContent = "Run Alignment Guard";
        if (coherenceLoading) coherenceLoading.classList.add("hidden");
        alert("Select a project first.");
        return;
      }

      clearFeatureResults();
      setActiveView("coherence");

      const res = await fetch("/coherence", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ project })
      });
      const data = await res.json();
      if (!res.ok) {
        coherenceSummary.textContent = data.message || "Alignment guard failed.";
        coherenceCards.innerHTML = "";
        return;
      }

      coherenceSummary.innerHTML = renderCoherenceSummary(data.summary || {});
      coherenceCards.innerHTML = "";

      (data.pairs || []).forEach((pair) => {
        const card = document.createElement("div");
        card.className = "card";
        const scoreClass = `score-${Math.max(1, Math.min(5, Number(pair.alignment_score) || 1))}`;
        card.innerHTML = `
          <div class="card-header">
            <strong>${escapeHtml(pair.label || pair.id)}</strong>
            <span class="score-pill ${scoreClass}">Score: ${escapeHtml(pair.alignment_score)}</span>
          </div>
          <div class="card-actions">
            <button class="toggle toggle-details">Details</button>
            <button class="toggle toggle-raw">Raw JSON</button>
          </div>
          ${renderCoherenceDetails(pair)}
        `;
        card.querySelector(".toggle-details").addEventListener("click", () => {
          card.querySelector(".details-panel").classList.toggle("hidden");
        });
        card.querySelector(".toggle-raw").addEventListener("click", () => {
          card.querySelector(".raw-json").classList.toggle("hidden");
        });
        coherenceCards.appendChild(card);
      });
    } finally {
      coherenceButton.disabled = false;
      coherenceButton.textContent = "Run Alignment Guard";
      if (coherenceLoading) coherenceLoading.classList.add("hidden");
    }
  });
}

setActiveView(activeView);
