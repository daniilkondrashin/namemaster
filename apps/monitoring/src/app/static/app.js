const state = {
  source: null,
  fallbackTimer: null,
};

function text(id, value) {
  document.getElementById(id).textContent = value;
}

function fmtNumber(value, digits = 3) {
  if (value === null || value === undefined) {
    return "-";
  }
  return Number(value).toFixed(digits).replace(/\.?0+$/, "");
}

function fmtBytes(value) {
  if (value === null || value === undefined) {
    return "-";
  }
  const units = ["B", "KiB", "MiB", "GiB", "TiB"];
  let number = Number(value);
  let unit = 0;
  while (number >= 1024 && unit < units.length - 1) {
    number /= 1024;
    unit += 1;
  }
  return `${fmtNumber(number, 2)} ${units[unit]}`;
}

function fmtDate(value) {
  if (!value) {
    return "-";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString();
}

function statusClass(value) {
  const normalized = String(value).toLowerCase();
  if (normalized === "ready" || normalized === "running") {
    return "ready";
  }
  if (normalized === "pending") {
    return "pending";
  }
  if (normalized === "notready" || normalized === "failed") {
    return "not-ready";
  }
  return "";
}

function cell(value, className = "") {
  const td = document.createElement("td");
  td.textContent = value;
  if (className) {
    td.className = className;
  }
  return td;
}

function emptyRow(tbody, colspan, message) {
  const tr = document.createElement("tr");
  tr.appendChild(cell(message));
  tr.firstChild.colSpan = colspan;
  tbody.appendChild(tr);
}

function renderPods(pods) {
  const tbody = document.getElementById("namemaster-pods");
  tbody.replaceChildren();
  if (!pods.length) {
    emptyRow(tbody, 8, "No namemaster pods found");
    return;
  }
  for (const pod of pods) {
    const tr = document.createElement("tr");
    tr.appendChild(cell(pod.name));
    tr.appendChild(cell(pod.namespace));
    tr.appendChild(cell(pod.node || "-"));
    tr.appendChild(cell(pod.phase, statusClass(pod.phase)));
    tr.appendChild(cell(`${fmtNumber(pod.cpu_usage_cores)} cores`));
    tr.appendChild(cell(fmtBytes(pod.memory_usage_bytes)));
    tr.appendChild(cell(pod.restarts));
    tr.appendChild(cell(fmtDate(pod.created_at)));
    tbody.appendChild(tr);
  }
}

function renderNodes(nodes) {
  const tbody = document.getElementById("nodes");
  tbody.replaceChildren();
  if (!nodes.length) {
    emptyRow(tbody, 12, "No nodes found");
    return;
  }
  for (const node of nodes) {
    const status = node.ready ? "Ready" : "NotReady";
    const tr = document.createElement("tr");
    tr.appendChild(cell(node.name));
    tr.appendChild(cell(status, statusClass(status)));
    tr.appendChild(cell(`${fmtNumber(node.cpu_usage_cores)} cores`));
    tr.appendChild(cell(`${fmtNumber(node.cpu_allocatable_cores)} cores`));
    tr.appendChild(cell(node.cpu_usage_percent === null ? "-" : `${fmtNumber(node.cpu_usage_percent, 2)}%`));
    tr.appendChild(cell(fmtBytes(node.memory_usage_bytes)));
    tr.appendChild(cell(fmtBytes(node.memory_allocatable_bytes)));
    tr.appendChild(cell(node.memory_usage_percent === null ? "-" : `${fmtNumber(node.memory_usage_percent, 2)}%`));
    tr.appendChild(cell(node.pod_count));
    tr.appendChild(cell(node.instance_type || "-"));
    tr.appendChild(cell(node.zone || "-"));
    tr.appendChild(cell(fmtDate(node.created_at)));
    tbody.appendChild(tr);
  }
}

function renderHistory(history) {
  const tbody = document.getElementById("history");
  tbody.replaceChildren();
  const recent = history.slice(-20).reverse();
  if (!recent.length) {
    emptyRow(tbody, 8, "No history yet");
    return;
  }
  for (const point of recent) {
    const tr = document.createElement("tr");
    tr.appendChild(cell(fmtDate(point.timestamp)));
    tr.appendChild(cell(point.node_count));
    tr.appendChild(cell(point.ready_node_count));
    tr.appendChild(cell(`${fmtNumber(point.cluster_cpu_usage_cores)} cores`));
    tr.appendChild(cell(fmtBytes(point.cluster_memory_usage_bytes)));
    tr.appendChild(cell(`${fmtNumber(point.namemaster_cpu_usage_cores)} cores`));
    tr.appendChild(cell(fmtBytes(point.namemaster_memory_usage_bytes)));
    tr.appendChild(cell(point.pending_pod_count, point.pending_pod_count > 0 ? "pending" : ""));
    tbody.appendChild(tr);
  }
}

function renderEvents(events) {
  const list = document.getElementById("events");
  list.replaceChildren();
  const recent = events.slice(-20).reverse();
  if (!recent.length) {
    const item = document.createElement("li");
    item.textContent = "No events yet";
    list.appendChild(item);
    return;
  }
  for (const event of recent) {
    const item = document.createElement("li");
    item.className = event.severity || "";
    item.textContent = `${fmtDate(event.timestamp)} - ${event.message}`;
    list.appendChild(item);
  }
}

function render(snapshot) {
  const summary = snapshot.summary;
  text("last-update", fmtDate(snapshot.generated_at));
  text("node-count", summary.node_count);
  text("ready-node-count", summary.ready_node_count);
  text("running-pod-count", summary.running_pod_count);
  text("pending-pod-count", summary.pending_pod_count);
  text("failed-pod-count", summary.failed_pod_count);
  text("cluster-cpu", `${fmtNumber(summary.cluster_cpu_usage_cores)} cores`);
  text("cluster-memory", fmtBytes(summary.cluster_memory_usage_bytes));
  text("namemaster-cpu", `${fmtNumber(summary.namemaster_cpu_usage_cores)} cores`);
  text("namemaster-memory", fmtBytes(summary.namemaster_memory_usage_bytes));

  const errors = document.getElementById("errors");
  if (snapshot.errors && snapshot.errors.length) {
    errors.hidden = false;
    errors.textContent = snapshot.errors.join(" | ");
  } else {
    errors.hidden = true;
    errors.textContent = "";
  }

  renderPods(snapshot.namemaster_pods || []);
  renderNodes(snapshot.nodes || []);
  renderHistory(snapshot.history || []);
  renderEvents(snapshot.recent_events || []);
}

async function fetchSnapshot() {
  const response = await fetch("/api/snapshot", { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Snapshot request failed: ${response.status}`);
  }
  render(await response.json());
}

function startFallback() {
  if (state.fallbackTimer) {
    return;
  }
  fetchSnapshot().catch((error) => console.error(error));
  state.fallbackTimer = window.setInterval(() => {
    fetchSnapshot().catch((error) => console.error(error));
  }, 5000);
}

function startSse() {
  if (!window.EventSource) {
    startFallback();
    return;
  }
  state.source = new EventSource("/api/events");
  state.source.addEventListener("snapshot", (event) => {
    render(JSON.parse(event.data));
  });
  state.source.onerror = () => {
    state.source.close();
    startFallback();
  };
}

startSse();
