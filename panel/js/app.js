import { listenToEvents, addEvent, updateEvent, deleteEvent, toggleEventStatus } from './events.js';
import { UI } from './ui.js';

// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', () => {
    // Initialize UI Manager
    const ui = new UI();
    
    // State to hold the ID of the event about to be deleted
    let currentDeleteId = null;

    /**
     * 1. INITIALIZE FIREBASE REALTIME LISTENER
     * This automatically triggers whenever data changes on Firebase.
     */
    listenToEvents((events, error) => {
        if (error) {
            ui.showToast('Failed to connect to Database. Please check firebase.js configuration.', 'error');
            ui.loadingState.innerHTML = '<i class="fa-solid fa-triangle-exclamation text-danger"></i> <p>Connection Error</p>';
            return;
        }
        // Update UI with fresh realtime data
        ui.setEvents(events);
    });

    /**
     * 2. HEADER CONTROLS
     */
    // Realtime Search
    document.getElementById('search-input').addEventListener('input', (e) => {
        ui.setSearchQuery(e.target.value);
    });

    // Open Add Modal
    document.getElementById('add-event-btn').addEventListener('click', () => {
        ui.openEventModal();
    });

    /**
     * 3. MODAL CLOSING BINDINGS
     */
    document.getElementById('close-modal-btn').addEventListener('click', () => ui.closeEventModal());
    document.getElementById('cancel-modal-btn').addEventListener('click', () => ui.closeEventModal());
    document.getElementById('close-delete-modal').addEventListener('click', () => ui.closeDeleteModal());
    document.getElementById('cancel-delete-btn').addEventListener('click', () => ui.closeDeleteModal());

    /**
     * 4. DYNAMIC COMMAND FORM BINDINGS
     */
    document.getElementById('add-cmd-btn').addEventListener('click', () => {
        ui.addCommandInput();
    });

    /**
     * 5. EVENT FORM SUBMISSION (ADD / EDIT)
     */
    document.getElementById('event-form').addEventListener('submit', async (e) => {
        e.preventDefault(); // Prevent page reload
        
        const id = document.getElementById('event-id').value;
        const cmds = ui.getCommandValues();
        
        // Validation
        if (cmds.length === 0) {
            ui.showToast('Please add at least one valid command', 'error');
            return;
        }

        // Construct Event Payload
        const eventData = {
            category: document.getElementById('event-category').value.trim(),
            name: document.getElementById('event-name').value.trim(),
            desc: document.getElementById('event-desc').value.trim(),
            delay: parseInt(document.getElementById('event-delay').value) || 0,
            enabled: document.getElementById('event-status').checked,
            cmds: cmds
        };

        // UI Loading State on Button
        const submitBtn = e.target.querySelector('button[type="submit"]');
        const originalText = submitBtn.innerHTML;
        submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Saving...';
        submitBtn.disabled = true;

        try {
            if (id) {
                // Update Existing
                await updateEvent(id, eventData);
                ui.showToast('Event updated successfully');
            } else {
                // Create New
                await addEvent(eventData);
                ui.showToast('Event created successfully');
            }
            ui.closeEventModal();
        } catch (error) {
            ui.showToast('Failed to save event. Check console.', 'error');
        } finally {
            // Restore button
            submitBtn.innerHTML = originalText;
            submitBtn.disabled = false;
        }
    });

    /**
     * 6. EVENT GRID EVENT DELEGATION
     * Handles clicks on dynamically created cards (Toggle, Edit, Delete)
     */
    document.getElementById('event-grid').addEventListener('click', async (e) => {
        // Find closest button element clicked
        const btn = e.target.closest('button');
        if (!btn) return;

        const id = btn.getAttribute('data-id');

        // ACTION: Toggle Status
        if (btn.classList.contains('toggle-btn')) {
            const currentStatus = btn.getAttribute('data-status') === 'true';
            
            // Optimistic UI lock
            btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i>';
            btn.disabled = true;
            
            try {
                await toggleEventStatus(id, currentStatus);
                ui.showToast(`Event ${currentStatus ? 'disabled' : 'enabled'}`);
            } catch (error) {
                ui.showToast('Failed to update status', 'error');
                // Realtime sync will fix the button UI if it fails
            }
        } 
        
        // ACTION: Edit
        else if (btn.classList.contains('edit-btn')) {
            const eventData = ui.events.find(ev => ev.id === id);
            if (eventData) {
                ui.openEventModal(eventData);
            }
        }
        
        // ACTION: Delete Trigger
        else if (btn.classList.contains('delete-btn')) {
            currentDeleteId = id;
            ui.openDeleteModal();
        }
    });

    /**
     * 7. DELETE CONFIRMATION HANDLER
     */
    document.getElementById('confirm-delete-btn').addEventListener('click', async (e) => {
        if (!currentDeleteId) return;
        
        const btn = e.target;
        const originalText = btn.innerHTML;
        
        btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Deleting...';
        btn.disabled = true;

        try {
            await deleteEvent(currentDeleteId);
            ui.showToast('Event permanently deleted');
            ui.closeDeleteModal();
        } catch (error) {
            ui.showToast('Failed to delete event', 'error');
        } finally {
            btn.innerHTML = originalText;
            btn.disabled = false;
            currentDeleteId = null; // reset
        }
    });
});
