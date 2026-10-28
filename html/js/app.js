const resourceName = (() => {
  try { return GetParentResourceName(); } catch (_) { return 'nova-ui'; }
})();

const tones = {
  primary: { title: 'INFO', rgb: '200, 160, 64' },
  info: { title: 'INFO', rgb: '75, 163, 255' },
  success: { title: 'SUCCESS', rgb: '76, 192, 96' },
  error: { title: 'ERROR', rgb: '208, 72, 72' },
  warning: { title: 'WARNING', rgb: '200, 160, 64' },
};

const notifyStack = document.getElementById('notify-stack');
const documentCard = document.getElementById('document-card');
const documentBadge = document.getElementById('document-badge');
const documentKicker = document.getElementById('document-kicker');
const documentTitle = document.getElementById('document-title');
const documentFields = document.getElementById('document-fields');
const documentFooter = document.getElementById('document-footer');
const documentLine = document.getElementById('document-line');
const confirmLayer = document.getElementById('confirm-layer');
const confirmTitle = document.getElementById('confirm-title');
const confirmMessage = document.getElementById('confirm-message');
const confirmAccept = document.getElementById('confirm-accept');
const confirmReject = document.getElementById('confirm-reject');
const confirmProgress = document.getElementById('confirm-progress-fill');
const progressWrap = document.getElementById('progress-wrap');
const progressLabel = document.getElementById('progress-label');
const progressPercent = document.getElementById('progress-percent');
const progressFill = document.getElementById('progress-fill');

let activeConfirm = null;
let confirmTimer = null;
let documentTimer = null;
let progressTimer = null;
let progressStartedAt = 0;
let progressDuration = 0;

function postNui(eventName, payload = {}) {
  return fetch(`https://${resourceName}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload),
  })
    .then((r) => (r && r.json) ? r.json().catch(() => ({})) : {})
    .catch(() => ({}));  // NUI iframe restart spam'i onle
}

function showNotify(data = {}) {
  const type = data.type || 'primary';
  const tone = tones[type] || tones.primary;
  const duration = Number(data.duration) || 4500;
  const item = document.createElement('div');
  item.className = 'notify';
  item.style.setProperty('--tone-rgb', tone.rgb);

  const title = document.createElement('div');
  title.className = 'notify-title';
  title.textContent = data.title || tone.title;

  const message = document.createElement('div');
  message.className = 'notify-message';
  message.textContent = data.message || '';

  const bar = document.createElement('span');
  bar.className = 'notify-bar';
  bar.style.animationDuration = `${duration}ms`;

  item.append(title, message, bar);
  notifyStack.appendChild(item);

  window.setTimeout(() => {
    item.style.opacity = '0';
    item.style.transform = 'translateX(16px)';
    item.style.transition = 'opacity 140ms ease, transform 140ms ease';
    window.setTimeout(() => item.remove(), 160);
  }, duration);
}

function resetDocumentPosition() {
  // CSS varsayılanına dön (ekran ortası-alt), inline sürükleme konumlarını temizle
  documentCard.style.left = '';
  documentCard.style.top = '';
  documentCard.style.bottom = '';
  documentCard.style.transform = '';
}

function hideDocument() {
  documentCard.classList.add('hidden');
}

function closeDocumentCard() {
  if (documentCard.classList.contains('hidden')) return;
  hideDocument();
  postNui('closeDocument');
}

function showDocument(data = {}) {
  const fields = Array.isArray(data.fields) ? data.fields : [];

  documentCard.className = data.type === 'registration' ? 'registration' : '';
  documentBadge.textContent = data.badge || 'N';
  documentKicker.textContent = data.kicker || 'BELGE';
  documentTitle.textContent = data.title || 'Belge';
  documentFooter.textContent = data.footer || 'Roleplay';
  documentFields.innerHTML = '';

  fields.forEach((field) => {
    const row = document.createElement('div');
    row.className = 'document-row';

    const label = document.createElement('span');
    label.textContent = field.label || '';

    const value = document.createElement('strong');
    value.textContent = field.value || '-';

    row.append(label, value);
    documentFields.appendChild(row);
  });

  resetDocumentPosition();
  documentCard.classList.remove('hidden');
}

/* ── Belge kartı: kapatma + sürükleme ── */
const documentClose = document.getElementById('document-close');
const documentHead = documentCard.querySelector('.document-head');
let docDrag = null;

if (documentClose) {
  documentClose.addEventListener('click', (e) => {
    e.stopPropagation();
    closeDocumentCard();
  });
}

if (documentHead) {
  documentHead.addEventListener('mousedown', (e) => {
    if (e.target.closest('#document-close')) return;
    const rect = documentCard.getBoundingClientRect();
    documentCard.style.left = rect.left + 'px';
    documentCard.style.top = rect.top + 'px';
    documentCard.style.bottom = 'auto';
    documentCard.style.transform = 'none';
    docDrag = { x: e.clientX - rect.left, y: e.clientY - rect.top };
    e.preventDefault();
  });
}

document.addEventListener('mousemove', (e) => {
  if (!docDrag) return;
  let x = e.clientX - docDrag.x;
  let y = e.clientY - docDrag.y;
  x = Math.max(0, Math.min(window.innerWidth - documentCard.offsetWidth, x));
  y = Math.max(0, Math.min(window.innerHeight - documentCard.offsetHeight, y));
  documentCard.style.left = x + 'px';
  documentCard.style.top = y + 'px';
});

document.addEventListener('mouseup', () => { docDrag = null; });

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && !documentCard.classList.contains('hidden')) {
    closeDocumentCard();
  }
});

function closeConfirm(accepted) {
  if (!activeConfirm) return;

  const id = activeConfirm.id;
  activeConfirm = null;
  confirmLayer.classList.add('hidden');
  window.clearTimeout(confirmTimer);
  confirmTimer = null;
  postNui('confirmResult', { id, accepted });
}

function showConfirm(data = {}) {
  activeConfirm = data;
  confirmTitle.textContent = data.title || 'Onay';
  confirmMessage.textContent = data.message || '';
  confirmAccept.textContent = data.acceptLabel || 'Kabul Et';
  
  if (data.rejectLabel === false || data.rejectLabel === null || data.rejectLabel === '') {
    confirmReject.style.display = 'none';
  } else {
    confirmReject.style.display = 'block';
    confirmReject.textContent = data.rejectLabel || 'Reddet';
  }

  confirmProgress.style.animation = 'none';
  confirmProgress.offsetHeight;
  confirmProgress.style.animation = `shrink ${Number(data.timeout) || 30000}ms linear forwards`;
  confirmLayer.classList.remove('hidden');

  window.clearTimeout(confirmTimer);
  confirmTimer = window.setTimeout(() => closeConfirm(false), Number(data.timeout) || 30000);
}

function stopProgress() {
  window.clearInterval(progressTimer);
  progressTimer = null;
  progressWrap.classList.add('hidden');
  progressFill.style.width = '0%';
  progressPercent.textContent = '0%';
}

function showProgress(data = {}) {
  window.clearInterval(progressTimer);

  progressDuration = Math.max(Number(data.duration) || 5000, 100);
  progressStartedAt = Date.now();
  progressLabel.textContent = data.label || 'Islem...';
  progressPercent.textContent = '0%';
  progressFill.style.width = '0%';
  progressWrap.classList.remove('hidden');

  progressTimer = window.setInterval(() => {
    const elapsed = Date.now() - progressStartedAt;
    const progress = Math.min(elapsed / progressDuration, 1);
    const percent = Math.floor(progress * 100);
    progressFill.style.width = `${percent}%`;
    progressPercent.textContent = `${percent}%`;

    if (progress >= 1) {
      stopProgress();
    }
  }, 80);
}

confirmAccept.addEventListener('click', () => closeConfirm(true));
confirmReject.addEventListener('click', () => closeConfirm(false));

document.addEventListener('keydown', (event) => {
  if (!activeConfirm) return;
  if (event.key === 'Enter') closeConfirm(true);
  if (event.key === 'Escape') closeConfirm(false);
});

// ── TextUI: persistent ipucu (sag-orta gibi sabit konumda) ───────────────
const textuiEl    = document.getElementById('textui');
const textuiIcon  = document.getElementById('textui-icon');
const textuiLabel = document.getElementById('textui-label');

// Allow only the tags the stylesheet uses. Everything else stays text.
function formatTextUi(raw) {
  const escaped = String(raw)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  return escaped.replace(/&lt;(\/?)(strong|br)\s*\/?&gt;/gi, function (_, slash, tag) {
    return '<' + slash + tag.toLowerCase() + '>';
  });
}

function showTextUI(data) {
  if (!textuiEl || !data) return;
  const text = String(data.text || '');
  const pos  = String(data.position || 'right-center');
  const icon = data.icon ? String(data.icon) : '';
  textuiEl.setAttribute('data-position', pos);
  if (icon !== '') {
    textuiIcon.textContent = icon.length <= 2 ? icon : icon.charAt(0).toUpperCase();
    textuiIcon.classList.remove('hidden');
  } else {
    textuiIcon.classList.add('hidden');
  }
  textuiLabel.innerHTML = formatTextUi(text);
  textuiEl.classList.remove('hidden');
}

function hideTextUI() {
  if (textuiEl) textuiEl.classList.add('hidden');
}

// ── Web Audio API sound synthesizer (no files needed) ───────────────────
let audioCtx = null;

function playSound(type) {
  if (typeof Config !== 'undefined' && Config.PlaySounds === false) return;
  try {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }

    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.connect(gain);
    gain.connect(audioCtx.destination);

    const now = audioCtx.currentTime;

    if (type === 'notify') {
      osc.type = 'sine';
      osc.frequency.setValueAtTime(523.25, now); // C5
      osc.frequency.setValueAtTime(659.25, now + 0.08); // E5
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(0.12, now + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
      osc.start(now);
      osc.stop(now + 0.4);
    } else if (type === 'click') {
      osc.type = 'sine';
      osc.frequency.setValueAtTime(900, now);
      gain.gain.setValueAtTime(0.06, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
      osc.start(now);
      osc.stop(now + 0.05);
    } else if (type === 'success') {
      osc.type = 'sine';
      osc.frequency.setValueAtTime(523.25, now);
      osc.frequency.setValueAtTime(659.25, now + 0.07);
      osc.frequency.setValueAtTime(783.99, now + 0.14);
      osc.frequency.setValueAtTime(1046.50, now + 0.21);
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(0.10, now + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5);
      osc.start(now);
      osc.stop(now + 0.55);
    } else if (type === 'fail') {
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(140, now);
      osc.frequency.linearRampToValueAtTime(70, now + 0.24);
      gain.gain.setValueAtTime(0.08, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.28);
      osc.start(now);
      osc.stop(now + 0.3);
    }
  } catch (e) {
    console.error('Audio synthesis failed:', e);
  }
}

// Intercept original visual cues to play synthesized audio
const originalShowNotify = showNotify;
showNotify = function(data) {
  originalShowNotify(data);
  playSound('notify');
};

const originalShowDocument = showDocument;
showDocument = function(data) {
  originalShowDocument(data);
  playSound('notify');
};

const originalShowConfirm = showConfirm;
showConfirm = function(data) {
  originalShowConfirm(data);
  playSound('notify');
};

// ── Context Menu Logic ──────────────────────────────────────────────────
const menuLayer = document.getElementById('menu-layer');
const menuTitle = document.getElementById('menu-title');
const menuOptionsContainer = document.getElementById('menu-options');

let menuVisible = false;
let activeMenuId = null;
let menuSelectedIdx = 0;
let menuOptionsCount = 0;

function showMenu(data = {}) {
  activeMenuId = data.id;
  menuTitle.textContent = data.title || 'Menu';
  menuOptionsContainer.innerHTML = '';
  menuSelectedIdx = 0;

  const options = Array.isArray(data.options) ? data.options : [];
  menuOptionsCount = options.length;

  if (menuOptionsCount === 0) return;

  options.forEach((opt, idx) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'menu-option';
    if (idx === 0) btn.classList.add('selected');

    if (opt.icon) {
      const iconSpan = document.createElement('span');
      iconSpan.className = 'menu-option-icon';
      iconSpan.textContent = String(opt.icon).substring(0, 2).toUpperCase();
      btn.appendChild(iconSpan);
    }

    const content = document.createElement('div');
    content.className = 'menu-option-content';

    const title = document.createElement('div');
    title.className = 'menu-option-title';
    title.textContent = opt.label || '';
    content.appendChild(title);

    if (opt.desc) {
      const desc = document.createElement('div');
      desc.className = 'menu-option-desc';
      desc.textContent = opt.desc;
      content.appendChild(desc);
    }

    btn.appendChild(content);

    if (opt.arrow) {
      const arrow = document.createElement('span');
      arrow.className = 'menu-option-arrow';
      arrow.innerHTML = '&#9654;';
      btn.appendChild(arrow);
    }

    // Hover mouse highlights option
    btn.addEventListener('mouseenter', () => {
      selectMenuOption(idx);
    });

    btn.addEventListener('click', () => {
      confirmMenuSelection(idx);
    });

    menuOptionsContainer.appendChild(btn);
  });

  menuVisible = true;
  menuLayer.classList.remove('hidden');
  playSound('notify');
}

function selectMenuOption(idx) {
  if (!menuVisible || idx < 0 || idx >= menuOptionsCount) return;
  const elements = menuOptionsContainer.querySelectorAll('.menu-option');
  elements.forEach((el, i) => {
    if (i === idx) {
      el.classList.add('selected');
      el.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    } else {
      el.classList.remove('selected');
    }
  });
  if (menuSelectedIdx !== idx) {
    menuSelectedIdx = idx;
    playSound('click');
  }
}

function confirmMenuSelection(idx) {
  if (!menuVisible) return;
  playSound('click');
  postNui('menuSelectOption', { id: activeMenuId, index: idx + 1 });
}

function hideMenu() {
  if (!menuVisible) return;
  menuVisible = false;
  menuLayer.classList.add('hidden');
}

function cancelMenu() {
  if (!menuVisible) return;
  menuVisible = false;
  menuLayer.classList.add('hidden');
  playSound('fail');
  postNui('menuCancel', { id: activeMenuId });
}

// ── Input Dialog Logic ──────────────────────────────────────────────────
const inputLayer = document.getElementById('input-layer');
const inputTitle = document.getElementById('input-title');
const inputFieldsContainer = document.getElementById('input-fields');
const inputForm = document.getElementById('input-form');
const inputCancelBtn = document.getElementById('input-cancel');

let inputVisible = false;

function showInputDialog(data = {}) {
  inputTitle.textContent = data.title || 'Input Dialog';
  inputFieldsContainer.innerHTML = '';

  const fields = Array.isArray(data.fields) ? data.fields : [];

  fields.forEach((field, index) => {
    const group = document.createElement('div');
    group.className = 'input-field-group';

    const label = document.createElement('label');
    label.textContent = field.label || `Field ${index + 1}`;
    if (field.required) {
      const req = document.createElement('span');
      req.textContent = '*';
      label.appendChild(req);
    }
    group.appendChild(label);

    const type = field.type || 'text';

    if (type === 'select') {
      const select = document.createElement('select');
      select.name = `field_${index}`;
      if (field.required) select.required = true;

      const options = Array.isArray(field.options) ? field.options : [];
      options.forEach(opt => {
        const option = document.createElement('option');
        option.value = opt.value !== undefined ? opt.value : opt;
        option.textContent = opt.label !== undefined ? opt.label : opt;
        select.appendChild(option);
      });
      group.appendChild(select);
    } else if (type === 'checkbox') {
      const wrap = document.createElement('label');
      wrap.className = 'checkbox-wrapper';

      const check = document.createElement('input');
      check.type = 'checkbox';
      check.name = `field_${index}`;

      const span = document.createElement('span');
      span.textContent = field.description || '';

      wrap.append(check, span);
      group.appendChild(wrap);
    } else {
      const input = document.createElement('input');
      input.type = type === 'password' ? 'password' : (type === 'number' ? 'number' : 'text');
      input.name = `field_${index}`;
      input.placeholder = field.placeholder || '';
      if (field.required) input.required = true;
      group.appendChild(input);
    }

    inputFieldsContainer.appendChild(group);
  });

  inputVisible = true;
  inputLayer.classList.remove('hidden');
  playSound('notify');

  // Auto-focus first input field
  const firstInput = inputFieldsContainer.querySelector('input, select');
  if (firstInput) firstInput.focus();
}

function submitInputDialog(e) {
  e.preventDefault();
  if (!inputVisible) return;

  const results = [];
  const fields = inputFieldsContainer.querySelectorAll('[name^="field_"]');
  fields.forEach(f => {
    if (f.type === 'checkbox') {
      results.push(f.checked);
    } else if (f.type === 'number') {
      results.push(f.value !== '' ? Number(f.value) : null);
    } else {
      results.push(f.value);
    }
  });

  inputVisible = false;
  inputLayer.classList.add('hidden');
  playSound('success');
  postNui('inputSubmit', { results });
}

function cancelInputDialog() {
  if (!inputVisible) return;
  inputVisible = false;
  inputLayer.classList.add('hidden');
  playSound('fail');
  postNui('inputCancel');
}

inputForm.addEventListener('submit', submitInputDialog);
if (inputCancelBtn) inputCancelBtn.addEventListener('click', cancelInputDialog);

// ── Skill Check Logic ───────────────────────────────────────────────────
const skillcheckLayer = document.getElementById('skillcheck-layer');
const skillcheckTarget = document.getElementById('skillcheck-target');
const skillcheckNeedle = document.getElementById('skillcheck-needle');
const skillcheckKeyEl = document.getElementById('skillcheck-key');
const skillcheckStageEl = document.getElementById('skillcheck-stage');

let skillcheckActive = false;
let skillcheckAngle = 0;
let skillcheckSpeed = 2.0;
let skillcheckTargetStart = 0;
let skillcheckTargetEnd = 0;
let skillcheckKey = 'E';
let skillcheckRotations = 0;
let skillcheckLastTime = 0;

// SVG Arc Math helpers
function polarToCartesian(centerX, centerY, radius, angleInDegrees) {
  const angleInRadians = (angleInDegrees - 90) * Math.PI / 180.0;
  return {
    x: centerX + (radius * Math.cos(angleInRadians)),
    y: centerY + (radius * Math.sin(angleInRadians))
  };
}

function drawArc(x, y, radius, startAngle, endAngle) {
  const start = polarToCartesian(x, y, radius, endAngle);
  const end = polarToCartesian(x, y, radius, startAngle);
  const largeArcFlag = endAngle - startAngle <= 180 ? "0" : "1";
  return [
    "M", start.x, start.y,
    "A", radius, radius, 0, largeArcFlag, 0, end.x, end.y
  ].join(" ");
}

function startSkillCheck(data = {}) {
  skillcheckAngle = 0;
  skillcheckRotations = 0;
  skillcheckSpeed = Number(data.speed) || 2.5;
  skillcheckKey = String(data.key || 'E').toUpperCase();
  skillcheckKeyEl.textContent = skillcheckKey;

  if (data.total && data.total > 1) {
    skillcheckStageEl.textContent = `${data.stage || 1}/${data.total}`;
    skillcheckStageEl.classList.remove('hidden');
  } else {
    skillcheckStageEl.classList.add('hidden');
  }

  // Set randomized success arc
  const zoneSize = Math.max(Number(data.zoneSize) || 45, 15);
  // Pick random starting point from 30 to 270 degrees
  skillcheckTargetStart = Math.floor(Math.random() * (260 - 30)) + 30;
  skillcheckTargetEnd = skillcheckTargetStart + zoneSize;

  // Draw SVG path
  skillcheckTarget.setAttribute('d', drawArc(50, 50, 40, skillcheckTargetStart, skillcheckTargetEnd));

  skillcheckActive = true;
  skillcheckLayer.classList.remove('hidden');
  skillcheckLastTime = performance.now();
  requestAnimationFrame(updateSkillCheckNeedle);
}

function updateSkillCheckNeedle(timestamp) {
  if (!skillcheckActive) return;

  const delta = (timestamp - skillcheckLastTime) / 16.666; // Normalize to 60fps
  skillcheckLastTime = timestamp;

  skillcheckAngle = (skillcheckAngle + skillcheckSpeed * delta);
  if (skillcheckAngle >= 360) {
    skillcheckAngle -= 360;
    skillcheckRotations++;
  }

  skillcheckNeedle.style.transform = `rotate(${skillcheckAngle}deg)`;

  // Fail if player exceeds 2 rotations without pressing key
  if (skillcheckRotations >= 2) {
    finishSkillCheck(false);
  } else {
    requestAnimationFrame(updateSkillCheckNeedle);
  }
}

function checkSkillCheckPress() {
  if (!skillcheckActive) return;

  let success = false;
  const angle = skillcheckAngle;
  const start = skillcheckTargetStart;
  const end = skillcheckTargetEnd;

  if (start <= end) {
    success = (angle >= start && angle <= end);
  } else {
    success = (angle >= start || angle <= end);
  }

  finishSkillCheck(success);
}

function finishSkillCheck(success) {
  if (!skillcheckActive) return;
  skillcheckActive = false;
  skillcheckLayer.classList.add('hidden');

  if (success) {
    playSound('success');
  } else {
    playSound('fail');
  }

  postNui('skillcheckResult', { success });
}

// ── Keyboard event router for Menu & Dialog cancellation ───────────────
document.addEventListener('keydown', (event) => {
  const key = event.key.toUpperCase();

  // Skill Check Input
  if (skillcheckActive && key === skillcheckKey) {
    event.preventDefault();
    checkSkillCheckPress();
    return;
  }

  // Menu Keyboard Control
  if (menuVisible) {
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      selectMenuOption((menuSelectedIdx + 1) % menuOptionsCount);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      selectMenuOption((menuSelectedIdx - 1 + menuOptionsCount) % menuOptionsCount);
    } else if (event.key === 'Enter') {
      event.preventDefault();
      confirmMenuSelection(menuSelectedIdx);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      cancelMenu();
    }
    return;
  }

  // Input Dialog Cancel
  if (inputVisible && event.key === 'Escape') {
    event.preventDefault();
    cancelInputDialog();
    return;
  }
});

// ── Master NUI Message Handler ──────────────────────────────────────────
window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action === 'notify') showNotify(data);
  if (action === 'document') showDocument(data);
  if (action === 'document:close') hideDocument();
  if (action === 'confirm') showConfirm(data);
  if (action === 'progress:start') showProgress(data);
  if (action === 'progress:stop') stopProgress();
  if (action === 'textui:show') showTextUI(data);
  if (action === 'textui:hide') hideTextUI();
  
  // New actions
  if (action === 'menu:show') showMenu(data);
  if (action === 'menu:hide') hideMenu();
  if (action === 'input:show') showInputDialog(data);
  if (action === 'input:hide') cancelInputDialog();
  if (action === 'skillcheck:start') startSkillCheck(data);
  if (action === 'skillcheck:keyPress') checkSkillCheckPress();
});
