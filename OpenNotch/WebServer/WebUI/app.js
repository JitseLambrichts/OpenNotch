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
    fontSize.value = config.appearance.fontSize;
    fontSizeValue.textContent = config.appearance.fontSize;
    bgOpacity.value = config.appearance.backgroundOpacity;
    bgOpacityValue.textContent = config.appearance.backgroundOpacity;
    enableHoverToOpen.checked = config.appearance.enableHoverToOpen !== false;

    // Bind change events
    accentColor.addEventListener('input', (e) => {
        config.appearance.accentColor = e.target.value;
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
}

// ── Save Indicator ────────────────────────

function showSaveIndicator() {
    const indicator = document.getElementById('save-indicator');
    indicator.classList.add('visible');
    setTimeout(() => {
        indicator.classList.remove('visible');
    }, 2000);
}
