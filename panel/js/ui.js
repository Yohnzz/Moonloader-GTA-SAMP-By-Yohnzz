export class UI {
    constructor() {
        // Application State
        this.events = [];
        this.categories = [];
        this.activeCategory = 'All';
        this.searchQuery = '';
        
        // Cache DOM Elements for performance
        this.eventGrid = document.getElementById('event-grid');
        this.categoryList = document.getElementById('category-list');
        this.loadingState = document.getElementById('loading-state');
        this.emptyState = document.getElementById('empty-state');
        this.toastContainer = document.getElementById('toast-container');
        
        // Modals
        this.eventModal = document.getElementById('event-modal');
        this.deleteModal = document.getElementById('delete-modal');
        
        // Form Elements
        this.eventForm = document.getElementById('event-form');
        this.commandList = document.getElementById('command-list');
        this.modalTitle = document.getElementById('modal-title');
    }

    /**
     * Updates internal state with fresh Firebase data and re-renders
     */
    setEvents(events) {
        this.events = events;
        this.extractCategories();
        this.render();
    }

    /**
     * Dynamically pulls unique categories from the dataset
     */
    extractCategories() {
        const cats = new Set(this.events.map(e => e.category));
        // Always include 'All' at the top
        this.categories = ['All', ...Array.from(cats).sort()];
    }

    /**
     * Filter handlers
     */
    setActiveCategory(category) {
        this.activeCategory = category;
        this.render();
    }

    setSearchQuery(query) {
        this.searchQuery = query.toLowerCase();
        this.render();
    }

    /**
     * Apply search and category filters
     */
    getFilteredEvents() {
        return this.events.filter(event => {
            const matchCategory = this.activeCategory === 'All' || event.category === this.activeCategory;
            const matchSearch = event.name.toLowerCase().includes(this.searchQuery) || 
                                event.desc.toLowerCase().includes(this.searchQuery) ||
                                event.category.toLowerCase().includes(this.searchQuery);
            return matchCategory && matchSearch;
        });
    }

    /**
     * Main UI Render pipeline
     */
    render() {
        // Hide loading initially
        this.loadingState.classList.add('hidden');
        
        // Render Sidebar
        this.renderCategories();
        
        const filteredEvents = this.getFilteredEvents();
        
        // Toggle Empty state vs Grid
        if (filteredEvents.length === 0) {
            this.emptyState.classList.remove('hidden');
            this.eventGrid.classList.add('hidden');
            this.eventGrid.innerHTML = '';
        } else {
            this.emptyState.classList.add('hidden');
            this.eventGrid.classList.remove('hidden');
            this.renderEventCards(filteredEvents);
        }
    }

    /**
     * Renders the sidebar category list
     */
    renderCategories() {
        this.categoryList.innerHTML = '';
        this.categories.forEach(category => {
            const li = document.createElement('li');
            if (category === this.activeCategory) li.classList.add('active');
            
            // Calculate item count for badges
            let count = category === 'All' 
                ? this.events.length 
                : this.events.filter(e => e.category === category).length;

            li.innerHTML = `
                <span>${category}</span>
                <span class="category-count">${count}</span>
            `;
            
            li.addEventListener('click', () => this.setActiveCategory(category));
            this.categoryList.appendChild(li);
        });
    }

    /**
     * Renders the dashboard cards based on filtered dataset
     */
    renderEventCards(eventsToRender) {
        this.eventGrid.innerHTML = '';
        
        eventsToRender.forEach(event => {
            const card = document.createElement('div');
            card.className = `event-card ${!event.enabled ? 'disabled' : ''}`;
            
            const cmdsCount = event.cmds ? event.cmds.length : 0;
            
            card.innerHTML = `
                <div class="card-header">
                    <span class="card-category">${event.category}</span>
                    <span class="card-status ${event.enabled ? 'status-active' : 'status-disabled'}">
                        ${event.enabled ? 'ACTIVE' : 'DISABLED'}
                    </span>
                </div>
                <h3 class="card-title">${event.name}</h3>
                <p class="card-desc">${event.desc}</p>
                
                <div class="card-meta">
                    <span title="Delay Between Commands">
                        <i class="fa-solid fa-clock"></i> ${event.delay}ms
                    </span>
                    <span title="Commands Count">
                        <i class="fa-solid fa-terminal"></i> ${cmdsCount} Cmds
                    </span>
                </div>
                
                <div class="card-actions">
                    <button class="btn btn-secondary btn-sm toggle-btn" data-id="${event.id}" data-status="${event.enabled}">
                        <i class="fa-solid fa-power-off"></i> ${event.enabled ? 'Disable' : 'Enable'}
                    </button>
                    <button class="btn btn-secondary btn-sm edit-btn" data-id="${event.id}">
                        <i class="fa-solid fa-pen"></i> Edit
                    </button>
                    <button class="btn btn-danger btn-sm delete-btn" data-id="${event.id}" title="Delete Event">
                        <i class="fa-solid fa-trash"></i>
                    </button>
                </div>
            `;
            this.eventGrid.appendChild(card);
        });
    }

    // --- Modal Management ---

    openEventModal(eventData = null) {
        this.eventForm.reset();
        this.commandList.innerHTML = ''; // clear commands
        
        if (eventData) {
            // Edit Mode
            this.modalTitle.textContent = 'Edit Event';
            document.getElementById('event-id').value = eventData.id;
            document.getElementById('event-category').value = eventData.category;
            document.getElementById('event-name').value = eventData.name;
            document.getElementById('event-desc').value = eventData.desc;
            document.getElementById('event-delay').value = eventData.delay;
            document.getElementById('event-status').checked = eventData.enabled;
            
            // Populate commands
            if (eventData.cmds && eventData.cmds.length > 0) {
                eventData.cmds.forEach(cmd => this.addCommandInput(cmd));
            } else {
                this.addCommandInput(); // At least one empty input
            }
        } else {
            // Add Mode
            this.modalTitle.textContent = 'Add New Event';
            document.getElementById('event-id').value = '';
            document.getElementById('event-status').checked = true;
            this.addCommandInput(); // Give an initial empty input
        }
        
        // Show modal with animation
        this.eventModal.classList.remove('hidden');
        // small delay to allow display:block to apply before animating opacity/transform
        setTimeout(() => this.eventModal.classList.add('active'), 10);
    }

    closeEventModal() {
        this.eventModal.classList.remove('active');
        setTimeout(() => this.eventModal.classList.add('hidden'), 250);
    }

    openDeleteModal() {
        this.deleteModal.classList.remove('hidden');
        setTimeout(() => this.deleteModal.classList.add('active'), 10);
    }

    closeDeleteModal() {
        this.deleteModal.classList.remove('active');
        setTimeout(() => this.deleteModal.classList.add('hidden'), 250);
    }

    // --- Command List Dynamic Inputs ---

    addCommandInput(value = '') {
        const div = document.createElement('div');
        div.className = 'cmd-item';
        // escape double quotes to prevent breaking HTML attributes
        const safeValue = value.replace(/"/g, '&quot;');
        
        div.innerHTML = `
            <input type="text" class="cmd-input" value="${safeValue}" required placeholder="e.g. /fa PENGUMUMAN">
            <button type="button" class="remove-cmd-btn" title="Remove Command">
                <i class="fa-solid fa-times"></i>
            </button>
        `;
        
        // Remove button logic
        div.querySelector('.remove-cmd-btn').addEventListener('click', () => {
            if (this.commandList.children.length > 1) {
                div.remove();
            } else {
                this.showToast('You must have at least one command', 'error');
            }
        });
        
        this.commandList.appendChild(div);
    }

    getCommandValues() {
        const inputs = this.commandList.querySelectorAll('.cmd-input');
        // Map to array and strip empty/whitespace strings
        return Array.from(inputs).map(input => input.value.trim()).filter(val => val !== '');
    }

    // --- Toast Notification System ---

    showToast(message, type = 'success') {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        
        const icon = type === 'success' ? 'fa-check-circle' : 'fa-triangle-exclamation';
        toast.innerHTML = `<i class="fa-solid ${icon}"></i> <span>${message}</span>`;
        
        this.toastContainer.appendChild(toast);
        
        // Auto remove after 3 seconds
        setTimeout(() => {
            toast.style.animation = 'fadeOut 0.3s forwards';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }
}
