import { invoke } from "@tauri-apps/api/core";
import "./styles.css";

const statusButton = document.querySelector("#status-button");
const statusOutput = document.querySelector("#status-output");
const planButton = document.querySelector("#plan-button");
const planOutput = document.querySelector("#plan-output");
const tokenFileInput = document.querySelector("#token-file");

function render(target, payload) {
  target.textContent = typeof payload === "string" ? payload : JSON.stringify(payload, null, 2);
}

async function runAction(target, action) {
  target.textContent = "Working...";
  try {
    render(target, await action());
  } catch (error) {
    render(target, { error: String(error) });
  }
}

statusButton.addEventListener("click", () => {
  runAction(statusOutput, () => invoke("probe_powershell"));
});

planButton.addEventListener("click", () => {
  const tokenFile = tokenFileInput.value.trim();
  runAction(planOutput, () => invoke("plan_gateway_start", { tokenFile }));
});
