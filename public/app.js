const evaluateButton = document.getElementById("evaluate");

if (evaluateButton) {
  evaluateButton.addEventListener("click", async () => {
    const feature = document.getElementById("feature-input").value;
    const res = await fetch("/evaluate", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ feature_proposal: feature })
    });
    const data = await res.json();
    const summary = document.getElementById("summary");
    summary.textContent = `Recommendation: ${data.summary.recommendation}`;

    const cards = document.getElementById("cards");
    cards.innerHTML = "";
    data.evaluations.forEach((ev) => {
      const card = document.createElement("div");
      card.className = "card";
      card.innerHTML = `
        <div class="card-header">
          <strong>${ev.agent}</strong>
          <span>Score: ${ev.alignment_score}</span>
        </div>
        <button class="toggle">Details</button>
        <pre class="details hidden">${JSON.stringify(ev, null, 2)}</pre>
      `;
      card.querySelector(".toggle").addEventListener("click", () => {
        card.querySelector(".details").classList.toggle("hidden");
      });
      cards.appendChild(card);
    });
  });
}
