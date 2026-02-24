const DATA_PATHS = {
  json: "data/test-results.json",
  verdictMd: "data/final-verdict.md",
  defectsMd: "data/defects.md",
  findingsMd: "data/findings.md",
};

async function fetchOptionalText(path) {
  try {
    const response = await fetch(path, { cache: "no-store" });
    if (!response.ok) {
      return null;
    }
    return await response.text();
  } catch {
    return null;
  }
}

async function fetchOptionalJson(path) {
  const text = await fetchOptionalText(path);
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function normalizeStatus(value) {
  const status = String(value || "PENDING").toUpperCase();
  if (status === "PASS") return "pass";
  if (status === "FAIL") return "fail";
  return "pending";
}

function screenshotPath(path) {
  const input = String(path || "");
  if (!input) return "";
  if (input.startsWith("http://") || input.startsWith("https://")) return input;
  if (input.startsWith("screenshots/")) return input;
  if (input.startsWith("./screenshots/")) return input.slice(2);

  const marker = "/screenshots/";
  const markerIndex = input.indexOf(marker);
  if (markerIndex >= 0) {
    return "screenshots/" + input.slice(markerIndex + marker.length);
  }
  return input;
}

function renderMetadata(run) {
  const node = document.getElementById("run-metadata");
  if (!run) {
    node.innerHTML = '<div class="muted">No run metadata found.</div>';
    return;
  }

  const rows = [
    ["Run ID", run.id],
    ["Mode", run.mode],
    ["Baseline Ref", run.baselineRef],
    ["Target Ref", run.targetRef],
    ["Bundle ID", run.bundleId],
    ["Simulator", run.simulator ? `${run.simulator.name || ""} (${run.simulator.udid || ""})` : ""],
    ["Runtime", run.simulator ? run.simulator.runtime : ""],
    ["Started At", run.startedAt],
    ["Ended At", run.endedAt],
  ];

  node.innerHTML = rows
    .map(([label, value]) => `<dt>${escapeHtml(label)}</dt><dd>${escapeHtml(value || "-")}</dd>`)
    .join("");
}

function renderVerdict(data) {
  const verdict = data?.verdict || {};
  const status = normalizeStatus(verdict.status);
  const summaryNode = document.getElementById("run-summary");
  const badgeNode = document.getElementById("verdict-badge");

  badgeNode.className = `badge ${status}`;
  badgeNode.textContent = (verdict.status || "PENDING").toUpperCase();
  summaryNode.textContent = verdict.summary || "No verdict summary provided.";
}

function renderGates(data) {
  const node = document.getElementById("gate-checks");
  const gates = data?.verdict?.gates || [];
  if (gates.length === 0) {
    node.innerHTML = '<div class="muted">No gate checks recorded.</div>';
    return;
  }
  node.innerHTML = gates
    .map((gate) => {
      const statusClass = normalizeStatus(gate.status);
      const evidence = Array.isArray(gate.evidence) && gate.evidence.length > 0
        ? `<div class="muted">Evidence: ${gate.evidence.map((item) => `<code>${escapeHtml(item)}</code>`).join(", ")}</div>`
        : "";
      return `
        <div class="check">
          <div>
            <div><strong>${escapeHtml(gate.name || "Gate")}</strong></div>
            <div class="muted">${escapeHtml(gate.details || "")}</div>
            ${evidence}
          </div>
          <div class="status ${statusClass}">${escapeHtml(String(gate.status || "PENDING").toUpperCase())}</div>
        </div>
      `;
    })
    .join("");
}

function renderPhases(data) {
  const node = document.getElementById("phase-list");
  const phases = data?.phases || [];
  if (phases.length === 0) {
    node.innerHTML = '<div class="muted">No phases recorded.</div>';
    return;
  }
  node.innerHTML = `<div class="list">${phases.map(renderPhase).join("")}</div>`;
}

function renderPhase(phase) {
  const checks = Array.isArray(phase.checks) ? phase.checks : [];
  const artifacts = Array.isArray(phase.artifacts) ? phase.artifacts : [];
  const shots = Array.isArray(phase.screenshots) ? phase.screenshots : [];

  const checksHtml = checks.length
    ? checks
        .map((check) => {
          const statusClass = normalizeStatus(check.status);
          return `
            <div class="check">
              <div>
                <strong>${escapeHtml(check.name || "Check")}</strong>
                <div class="muted">Expected: ${escapeHtml(check.expected || "-")} | Actual: ${escapeHtml(check.actual || "-")}</div>
              </div>
              <div class="status ${statusClass}">${escapeHtml(String(check.status || "PENDING").toUpperCase())}</div>
            </div>
          `;
        })
        .join("")
    : '<div class="muted">No checks logged for this phase.</div>';

  const artifactsHtml = artifacts.length
    ? `<div class="muted">Artifacts: ${artifacts
        .map((artifact) => `<code>${escapeHtml(artifact.path || artifact.label || "")}</code>`)
        .join(", ")}</div>`
    : "";

  const screenshotsHtml = shots.length
    ? `
      <div class="screenshot-grid">
        ${shots
          .map((shot) => {
            const src = screenshotPath(shot.path);
            return `
              <figure class="shot">
                <a href="${escapeHtml(src)}" target="_blank" rel="noopener noreferrer">
                  <img src="${escapeHtml(src)}" alt="${escapeHtml(shot.caption || src)}" loading="lazy" />
                </a>
                <figcaption>${escapeHtml(shot.caption || src)}</figcaption>
              </figure>
            `;
          })
          .join("")}
      </div>
    `
    : "";

  return `
    <article class="item">
      <h3>${escapeHtml(phase.name || "Phase")}</h3>
      <div class="muted">${escapeHtml(phase.summary || "")}</div>
      ${checksHtml}
      ${artifactsHtml}
      ${screenshotsHtml}
    </article>
  `;
}

function renderFindings(data) {
  const node = document.getElementById("findings-list");
  const findings = data?.findings || [];
  if (findings.length === 0) {
    node.innerHTML = '<div class="muted">No findings recorded.</div>';
    return;
  }
  node.innerHTML = `<div class="list">${findings
    .map((finding) => {
      const severity = String(finding.severity || "info").toLowerCase();
      const evidence = Array.isArray(finding.evidence) ? finding.evidence : [];
      return `
        <article class="item">
          <h3>${escapeHtml(finding.id || "Finding")} ${finding.title ? `- ${escapeHtml(finding.title)}` : ""}</h3>
          <div><span class="tag ${escapeHtml(severity)}">${escapeHtml(severity.toUpperCase())}</span></div>
          <p>${escapeHtml(finding.description || "")}</p>
          <div class="muted">${evidence.map((item) => `<code>${escapeHtml(item)}</code>`).join(", ")}</div>
        </article>
      `;
    })
    .join("")}</div>`;
}

function renderDefects(data) {
  const node = document.getElementById("defects-list");
  const defects = data?.defects || [];
  if (defects.length === 0) {
    node.innerHTML = '<div class="muted">No defects recorded.</div>';
    return;
  }
  node.innerHTML = `<div class="list">${defects
    .map((defect) => {
      const severity = String(defect.severity || "p3").toLowerCase();
      const evidence = Array.isArray(defect.evidence) ? defect.evidence : [];
      const steps = Array.isArray(defect.stepsToReproduce) ? defect.stepsToReproduce : [];
      return `
        <article class="item">
          <h3>${escapeHtml(defect.id || "Defect")} ${defect.title ? `- ${escapeHtml(defect.title)}` : ""}</h3>
          <div><span class="tag ${escapeHtml(severity)}">${escapeHtml(severity.toUpperCase())}</span></div>
          <p>${escapeHtml(defect.description || "")}</p>
          ${
            steps.length
              ? `<ol>${steps.map((step) => `<li>${escapeHtml(step)}</li>`).join("")}</ol>`
              : ""
          }
          <div class="muted">Expected: ${escapeHtml(defect.expected || "-")}</div>
          <div class="muted">Actual: ${escapeHtml(defect.actual || "-")}</div>
          <div class="muted">Status: ${escapeHtml(defect.status || "-")} ${defect.owner ? `| Owner: ${escapeHtml(defect.owner)}` : ""}</div>
          <div class="muted">${evidence.map((item) => `<code>${escapeHtml(item)}</code>`).join(", ")}</div>
        </article>
      `;
    })
    .join("")}</div>`;
}

function renderArtifacts(data) {
  const node = document.getElementById("artifact-list");
  const artifacts = data?.artifacts || [];
  if (artifacts.length === 0) {
    node.innerHTML = '<div class="muted">No artifacts recorded.</div>';
    return;
  }
  node.innerHTML = `<ul>${artifacts
    .map((artifact) => {
      const label = artifact.label || artifact.path || "artifact";
      const path = artifact.path || "";
      return `<li><strong>${escapeHtml(label)}:</strong> <code>${escapeHtml(path)}</code></li>`;
    })
    .join("")}</ul>`;
}

function renderMarkdownFallbacks(verdictMd, defectsMd, findingsMd) {
  const node = document.getElementById("markdown-fallbacks");
  const blocks = [];

  if (verdictMd) {
    blocks.push(markdownBlock("final-verdict.md", verdictMd));
  }
  if (defectsMd) {
    blocks.push(markdownBlock("defects.md", defectsMd));
  }
  if (findingsMd) {
    blocks.push(markdownBlock("findings.md", findingsMd));
  }

  if (blocks.length === 0) {
    node.innerHTML = '<div class="muted">No markdown report files found.</div>';
    return;
  }

  node.innerHTML = blocks.join("");
}

function markdownBlock(filename, content) {
  return `
    <article class="markdown-block">
      <h3>${escapeHtml(filename)}</h3>
      <pre>${escapeHtml(content)}</pre>
    </article>
  `;
}

async function init() {
  const [json, verdictMd, defectsMd, findingsMd] = await Promise.all([
    fetchOptionalJson(DATA_PATHS.json),
    fetchOptionalText(DATA_PATHS.verdictMd),
    fetchOptionalText(DATA_PATHS.defectsMd),
    fetchOptionalText(DATA_PATHS.findingsMd),
  ]);

  renderMetadata(json?.run);
  renderVerdict(json);
  renderGates(json);
  renderPhases(json);
  renderFindings(json);
  renderDefects(json);
  renderArtifacts(json);
  renderMarkdownFallbacks(verdictMd, defectsMd, findingsMd);
}

init();
