const $ = (id) => document.getElementById(id);
const draftKey = 'runner-message-draft-v1';
let environments = [];
let preview = null;
let busy = false;
let ready = false;
let token;
let draft;

function freshDraft(environment = '') {
  return { schemaVersion: 1, environment, attempted: false,
    message: { uid: '', sourceId: crypto.randomUUID(), title: '', body: '', goldAmount: 0 } };
}

function status(text, error = false) {
  $('status').textContent = text;
  $('status').className = error ? 'error' : '';
}

function persist(value = draft) {
  // Persist before sending so an uncertain response or browser restart keeps the same ID.
  localStorage.setItem(draftKey, JSON.stringify(value));
}

function controls() {
  $('fields').disabled = !ready || busy || draft.attempted;
  $('preview-button').disabled = !ready || busy || Boolean(draft.receipt);
  $('new-button').disabled = !ready || busy;
  $('export-button').disabled = !ready || busy;
  $('import-file').disabled = !ready || busy;
  $('send-button').disabled = !ready || busy || !preview || Boolean(draft.receipt);
  $('send-button').textContent = draft.receipt ? 'Delivered' : busy ? 'Working…' : draft.attempted ? 'Retry same delivery' :
    preview?.environment === 'prod' ? 'Send to production' : 'Send message';
}

function destination() {
  const selected = environments.find(({ name }) => name === draft.environment);
  $('destination').textContent = selected ? `${selected.name.toUpperCase()} · ${selected.projectId}` : "Select the player's environment.";
  $('destination').className = `destination${draft.environment === 'prod' ? ' production' : ''}`;
}

function renderDraft() {
  $('environment').value = draft.environment;
  for (const field of ['uid', 'title', 'body']) $(field).value = draft.message[field];
  $('gold').value = draft.message.goldAmount;
  $('source-id').textContent = draft.message.sourceId;
  destination();
  preview = null;
  $('preview').hidden = true;
  $('empty-preview').hidden = Boolean(draft.receipt);
  renderReceipt();
  controls();
}

function renderReceipt() {
  $('receipt').hidden = !draft.receipt;
  if (draft.receipt) {
    $('receipt-text').textContent = `${draft.receipt.environment.toUpperCase()} · ${draft.receipt.projectId}\nPlayer: ${draft.receipt.uid}\nMessage: ${draft.receipt.messageId}\nConfirmed: ${draft.receipt.confirmedAt}`;
  }
}

async function api(path, body) {
  const response = await fetch(path, {
    method: body ? 'POST' : 'GET',
    headers: { Authorization: `Bearer ${token}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(45_000),
  });
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'The console request failed.');
  return result;
}

function readDraftFile(value) {
  const m = value?.message;
  if (m?.attachments?.length) throw new Error('Open item and skill drafts in the Flutter Admin app.');
  if (value?.schemaVersion !== 1 || !environments.some(({ name }) => name === value.environment) ||
      !m || ['uid', 'sourceId', 'title', 'body'].some((key) => typeof m[key] !== 'string') ||
      !m.sourceId.trim() || !Number.isSafeInteger(m.goldAmount) || m.goldAmount < 0 ||
      (value.attempted !== undefined && typeof value.attempted !== 'boolean')) {
    throw new Error('Invalid draft file. Restore a draft downloaded from this console.');
  }
  return { schemaVersion: 1, environment: value.environment, attempted: value.attempted === true,
    message: { uid: m.uid, sourceId: m.sourceId, title: m.title, body: m.body, goldAmount: m.goldAmount } };
}

$('compose').addEventListener('input', () => {
  draft.environment = $('environment').value;
  for (const field of ['uid', 'title', 'body']) draft.message[field] = $(field).value;
  draft.message.goldAmount = Number($('gold').value);
  preview = null;
  $('preview').hidden = true;
  $('empty-preview').hidden = false;
  destination();
  try { persist(); status('Draft saved. Preview before sending.'); }
  catch { status('Browser storage is unavailable. Enable local storage before sending.', true); }
  controls();
});

$('compose').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (busy) return;
  busy = true;
  controls();
  try {
    persist();
    preview = await api('/api/preview', { environment: draft.environment, message: draft.message });
    $('preview-environment').textContent = `${preview.environment.toUpperCase()} · ${preview.projectId}`;
    $('preview-environment').className = `destination${preview.environment === 'prod' ? ' production' : ''}`;
    for (const key of ['uid', 'title', 'body']) $(`preview-${key}`).textContent = preview[key];
    $('preview-source').textContent = preview.sourceId;
    $('preview-gold').textContent = preview.goldAmount > 0 ? `${preview.goldAmount.toLocaleString()} gold to claim` : 'Message only · no gold';
    $('empty-preview').hidden = true;
    $('preview').hidden = false;
    status('Review the environment, player and contents before sending.');
  } catch (error) {
    preview = null;
    $('preview').hidden = true;
    status(error.message, true);
  } finally { busy = false; controls(); }
});

$('send-button').addEventListener('click', async () => {
  if (!preview || busy || draft.receipt) return;
  busy = true;
  draft.attempted = true;
  controls();
  try {
    persist();
    status(`Sending to ${preview.environment.toUpperCase()}…`);
    draft.receipt = await api('/api/send', { previewId: preview.previewId });
    persist();
    renderReceipt();
    status('Delivery confirmed. The message is available in the player’s inbox.');
  } catch (error) {
    status(`${error.message} Keep this draft and delivery ID. Re-preview if needed, then retry the same delivery.`, true);
  } finally { busy = false; controls(); }
});

$('new-button').addEventListener('click', () => {
  if (!confirm('Start a new message with a new delivery ID? Download the current draft first if you need to recover it.')) return;
  const next = freshDraft(draft.environment);
  try { persist(next); draft = next; renderDraft(); status('New draft. Enter one player UID and your message.'); }
  catch { status('Unable to save the new draft. Check browser storage.', true); }
});

$('export-button').addEventListener('click', () => {
  const { receipt, ...saved } = draft;
  const url = URL.createObjectURL(new Blob([JSON.stringify(saved, null, 2)], { type: 'application/json' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = 'message-draft.json';
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});

$('import-file').addEventListener('change', async () => {
  const file = $('import-file').files[0];
  if (!file) return;
  busy = true;
  controls();
  try {
    if (file.size > 32 * 1024) throw new Error('Draft file is too large.');
    const restored = readDraftFile(JSON.parse(await file.text()));
    if (!confirm('Replace the current draft with this saved delivery?')) return;
    persist(restored);
    draft = restored;
    renderDraft();
    status('Draft restored with its original delivery ID. Preview before sending or retrying.');
  } catch (error) { status(error.message, true); }
  finally { $('import-file').value = ''; busy = false; controls(); }
});

try {
  token = location.hash.slice(1) || sessionStorage.getItem('message-console-token');
  if (!token) throw new Error('Open the private local URL printed by the launcher.');
  sessionStorage.setItem('message-console-token', token);
  history.replaceState(null, '', '/');
  const configuration = await api('/api/environments');
  environments = configuration.environments;
  $('test-banner').hidden = !configuration.offlineTest;
  if (configuration.operatorAccount) {
    $('operator-account').textContent = `Messaging account: ${configuration.operatorAccount}`;
    $('operator-account').hidden = false;
  }
  for (const environment of environments) {
    const option = document.createElement('option');
    option.value = environment.name;
    option.textContent = environment.name === 'prod' ? 'Production' : environment.name === 'staging' ? 'Staging' : 'Development';
    $('environment').append(option);
  }
  const saved = localStorage.getItem(draftKey);
  draft = saved ? JSON.parse(saved) : freshDraft();
  if (draft.schemaVersion !== 1 || !draft.message) throw new Error('Saved draft is invalid. Restore a downloaded draft after clearing this site’s local storage.');
  ready = true;
  renderDraft();
  status(draft.receipt ? 'Previous delivery confirmed. Start a new message when ready.' :
    draft.attempted ? 'Previous send attempted. Preview this same draft to safely retry.' : 'Choose an environment and compose your message.');
} catch (error) { status(error.message, true); }
