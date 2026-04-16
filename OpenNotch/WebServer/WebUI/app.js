// ========================================
// OpenNotch Settings — Client-side logic
// ========================================

const API_BASE = '';
let config = null;
let saveTimeout = null;

// ── Init ──────────────────────────────────

document.addEventListener('DOMContentLoaded', async () => {
    await loadConfig();
    renderWidgets();
    bindAppearanceControls();
    bindClaudeCookieControls();
});

// ── API ───────────────────────────────────

async function loadConfig() {
    try {
        const res = await fetch(`${API_BASE}/api/config`);
        config = await res.json();
    } catch (err) {
        console.error('Failed to load config:', err);
        config = null;
    }
}

async function saveConfig() {
    if (!config) return;
    try {
        await fetch(`${API_BASE}/api/config`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(config)
        });
        showSaveIndicator();
    } catch (err) {
        console.error('Failed to save config:', err);
    }
}

function debouncedSave() {
    clearTimeout(saveTimeout);
    saveTimeout = setTimeout(saveConfig, 300);
}

// ── Widgets ───────────────────────────────

function renderWidgets() {
    const list = document.getElementById('widget-list');
    if (!config || !config.widgets) return;

    list.innerHTML = '';

    const sorted = [...config.widgets].sort((a, b) => a.order - b.order);

    if (!sorted.length) {
        const empty = document.createElement('div');
        empty.className = 'widget-item';
        empty.innerHTML = `
            <div class="widget-info">
                <div class="widget-name">No widgets configured</div>
                <div class="widget-id">Enable widgets in your config to populate this list.</div>
            </div>
        `;
        list.appendChild(empty);
        return;
    }

    sorted.forEach((widget, index) => {
        const item = document.createElement('div');
        item.className = 'widget-item';
        item.draggable = true;
        item.dataset.id = widget.id;
        item.dataset.index = index;

        item.innerHTML = `
            <span class="drag-handle">☰</span>
            <div class="widget-info">
                <div class="widget-name">${widget.displayName}</div>
                <div class="widget-id">${widget.id}</div>
            </div>
            <label class="toggle">
                <input type="checkbox" ${widget.enabled ? 'checked' : ''} data-widget-id="${widget.id}">
                <span class="toggle-slider"></span>
            </label>
        `;

        // Toggle handler
        const checkbox = item.querySelector('input[type="checkbox"]');
        checkbox.addEventListener('change', (e) => {
            const w = config.widgets.find(w => w.id === widget.id);
            if (w) {
                w.enabled = e.target.checked;
                debouncedSave();
            }
        });

        // Drag handlers
        item.addEventListener('dragstart', handleDragStart);
        item.addEventListener('dragend', handleDragEnd);
        item.addEventListener('dragover', handleDragOver);
        item.addEventListener('dragenter', handleDragEnter);
        item.addEventListener('dragleave', handleDragLeave);
        item.addEventListener('drop', handleDrop);

        list.appendChild(item);
    });
}

// ── Drag & Drop ───────────────────────────

let draggedItem = null;

function handleDragStart(e) {
    draggedItem = this;
    this.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', this.dataset.id);
}

function handleDragEnd(e) {
    this.classList.remove('dragging');
    document.querySelectorAll('.widget-item').forEach(item => {
        item.classList.remove('drag-over');
    });
    draggedItem = null;
}

function handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
}

function handleDragEnter(e) {
    e.preventDefault();
    if (this !== draggedItem) {
        this.classList.add('drag-over');
    }
}

function handleDragLeave(e) {
    this.classList.remove('drag-over');
}

function handleDrop(e) {
    e.preventDefault();
    this.classList.remove('drag-over');

    if (!draggedItem || this === draggedItem) return;

    const fromId = draggedItem.dataset.id;
    const toId = this.dataset.id;

    // Swap orders
    const fromWidget = config.widgets.find(w => w.id === fromId);
    const toWidget = config.widgets.find(w => w.id === toId);

    if (fromWidget && toWidget) {
        const tempOrder = fromWidget.order;
        fromWidget.order = toWidget.order;
        toWidget.order = tempOrder;

        renderWidgets();
        debouncedSave();
    }
}

// ── Appearance Controls ───────────────────

function bindAppearanceControls() {
    if (!config) return;

    const accentColor = document.getElementById('accentColor');
    const fontSize = document.getElementById('fontSize');
    const fontSizeValue = document.getElementById('fontSizeValue');
    const bgOpacity = document.getElementById('backgroundOpacity');
    const bgOpacityValue = document.getElementById('backgroundOpacityValue');
    const enableHoverToOpen = document.getElementById('enableHoverToOpen');

    // Set initial values
    accentColor.value = config.appearance.accentColor;
    applyAccentColor(config.appearance.accentColor);
    fontSize.value = config.appearance.fontSize;
    fontSizeValue.textContent = config.appearance.fontSize;
    bgOpacity.value = config.appearance.backgroundOpacity;
    bgOpacityValue.textContent = config.appearance.backgroundOpacity;
    enableHoverToOpen.checked = config.appearance.enableHoverToOpen !== false;

    // Bind change events
    accentColor.addEventListener('input', (e) => {
        config.appearance.accentColor = e.target.value;
        applyAccentColor(e.target.value);
        debouncedSave();
    });

    fontSize.addEventListener('input', (e) => {
        const val = parseFloat(e.target.value);
        config.appearance.fontSize = val;
        fontSizeValue.textContent = val;
        debouncedSave();
    });

    bgOpacity.addEventListener('input', (e) => {
        const val = parseFloat(e.target.value);
        config.appearance.backgroundOpacity = val;
        bgOpacityValue.textContent = val.toFixed(2);
        debouncedSave();
    });

    enableHoverToOpen.addEventListener('change', (e) => {
        config.appearance.enableHoverToOpen = e.target.checked;
        debouncedSave();
    });

    const showBar = document.getElementById('showClaudeUsageBar');
    showBar.checked = config.claudeUsage?.showBar !== false;
    showBar.addEventListener('change', (e) => {
        if (!config.claudeUsage) config.claudeUsage = {};
        config.claudeUsage.showBar = e.target.checked;
        debouncedSave();
    });
}

function applyAccentColor(color) {
    if (!color) return;
    document.documentElement.style.setProperty('--accent', color);
    const soft = hexToRgba(color, 0.15);
    document.documentElement.style.setProperty('--accent-soft', soft);
}

function hexToRgba(hex, alpha) {
    const safeHex = hex.replace('#', '').trim();
    if (safeHex.length !== 6) return `rgba(10, 132, 255, ${alpha})`;
    const r = parseInt(safeHex.slice(0, 2), 16);
    const g = parseInt(safeHex.slice(2, 4), 16);
    const b = parseInt(safeHex.slice(4, 6), 16);
    if ([r, g, b].some(Number.isNaN)) return `rgba(10, 132, 255, ${alpha})`;
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

// ── Claude Cookie Controls ────────────────

async function bindClaudeCookieControls() {
    const input = document.getElementById('claudeCookie');
    const saveBtn = document.getElementById('saveCookieBtn');
    const clearBtn = document.getElementById('clearCookieBtn');
    const statusEl = document.getElementById('cookieStatus');

    async function loadStatus() {
        try {
            const res = await fetch('/api/claude-cookie/status');
            const data = await res.json();
            if (data.hasCookie) {
                if (data.lastError) {
                    setStatus(data.lastError, 'error');
                } else {
                    setStatus('Cookie saved', 'ok');
                }
            } else {
                setStatus('No cookie set', 'muted');
            }
        } catch {
            setStatus('Could not reach server', 'error');
        }
    }

    function setStatus(msg, type) {
        statusEl.textContent = msg;
        statusEl.className = 'cookie-status ' + type;
    }

    saveBtn.addEventListener('click', async () => {
        const cookie = input.value.trim();
        if (!cookie) return;
        saveBtn.disabled = true;
        try {
            const res = await fetch('/api/claude-cookie', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ cookie })
            });
            if (res.ok) {
                input.value = '';
                setStatus('Cookie saved — fetching usage…', 'ok');
                setTimeout(loadStatus, 2000);
            } else {
                let errMsg = 'Failed to save cookie';
                try {
                    const body = await res.json();
                    if (body?.error) errMsg = body.error;
                } catch {
                    // Keep default message when response body is not JSON.
                }
                setStatus(errMsg, 'error');
            }
        } catch {
            setStatus('Network error', 'error');
        } finally {
            saveBtn.disabled = false;
        }
    });

    clearBtn.addEventListener('click', async () => {
        try {
            await fetch('/api/claude-cookie', { method: 'DELETE' });
            input.value = '';
            setStatus('Cookie cleared', 'muted');
        } catch {
            setStatus('Network error', 'error');
        }
    });

    await loadStatus();
}

// ── Save Indicator ────────────────────────

function showSaveIndicator() {
    const indicator = document.getElementById('save-indicator');
    indicator.classList.add('visible');
    setTimeout(() => {
        indicator.classList.remove('visible');
    }, 2000);
}
