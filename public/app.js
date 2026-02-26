const evaluateButton = document.getElementById("evaluate");
const loading = document.getElementById("loading");
const AGENT_LABELS = {
  strategy: "Strategy",
  vision: "Product Vision",
  jtbd: "Jobs to be done",
  user_flows: "User Flows",
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

function renderEvaluationDetails(ev) {
  const conflicts = Array.isArray(ev.detected_conflicts) ? ev.detected_conflicts : [];
  const actions = Array.isArray(ev.what_would_make_this_a_5_of_5) ? ev.what_would_make_this_a_5_of_5 : [];

  const conflictsHtml = conflicts.length
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
        <h4>Detected Conflicts</h4>
        ${conflictsHtml}
      </section>
      <section class="details-section">
        <h4>What Would Make This a 5/5</h4>
        ${actionsHtml}
      </section>
    </div>
    <pre class="raw-json hidden">${escapeHtml(JSON.stringify(ev, null, 2))}</pre>
  `;
}

if (evaluateButton) {
  evaluateButton.addEventListener("click", async () => {
    evaluateButton.disabled = true;
    evaluateButton.textContent = "Evaluating...";
    if (loading) loading.classList.remove("hidden");

    try {
      const feature = document.getElementById("feature-input").value;
      const res = await fetch("/evaluate", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ feature_proposal: feature })
      });
      const data = await res.json();
      const summary = document.getElementById("summary");
      const meta = data.meta || { total: 0, succeeded: 0, failed: 0 };
      summary.textContent = `Completed ${meta.succeeded}/${meta.total} evaluator runs (${meta.failed} failed).`;

      const cards = document.getElementById("cards");
      cards.innerHTML = "";
      data.evaluations.forEach((ev) => {
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
        cards.appendChild(card);
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
        cards.appendChild(card);
      });
    } finally {
      evaluateButton.disabled = false;
      evaluateButton.textContent = "Evaluate";
      if (loading) loading.classList.add("hidden");
    }
  });
}
