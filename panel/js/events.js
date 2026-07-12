import { db, ref, onValue, set, push, remove, update } from './firebase.js';

// The root node name in Realtime Database where events will be stored
export const EVENTS_PATH = 'events';

/**
 * Attaches a realtime listener to the events path.
 * @param {Function} callback - Function called when data changes (returns array of events)
 */
export function listenToEvents(callback) {
    const eventsRef = ref(db, EVENTS_PATH);
    
    onValue(eventsRef, (snapshot) => {
        const data = snapshot.val();
        const eventsList = [];
        
        if (data) {
            // Firebase returns an object with generated keys. We convert it to an array.
            Object.keys(data).forEach(key => {
                eventsList.push({
                    id: key,
                    ...data[key]
                });
            });
        }
        
        // Pass the events array back to the app layer
        callback(eventsList, null);
    }, (error) => {
        console.error("Firebase Read Error:", error);
        callback([], error);
    });
}

/**
 * Creates a new event in the database
 * @param {Object} eventData - The payload to save
 */
export async function addEvent(eventData) {
    try {
        const eventsRef = ref(db, EVENTS_PATH);
        // push() generates a unique random ID automatically
        const newEventRef = push(eventsRef);
        await set(newEventRef, eventData);
        return true;
    } catch (error) {
        console.error("Error adding event:", error);
        throw error;
    }
}

/**
 * Updates an existing event
 * @param {String} id - The Firebase node key of the event
 * @param {Object} eventData - The fields to update
 */
export async function updateEvent(id, eventData) {
    try {
        const eventRef = ref(db, `${EVENTS_PATH}/${id}`);
        await update(eventRef, eventData);
        return true;
    } catch (error) {
        console.error("Error updating event:", error);
        throw error;
    }
}

/**
 * Deletes an event permanently
 * @param {String} id - The Firebase node key of the event
 */
export async function deleteEvent(id) {
    try {
        const eventRef = ref(db, `${EVENTS_PATH}/${id}`);
        await remove(eventRef);
        return true;
    } catch (error) {
        console.error("Error deleting event:", error);
        throw error;
    }
}

/**
 * Quick toggle for event enabled/disabled status
 * @param {String} id - The Firebase node key
 * @param {Boolean} currentStatus - The current boolean status
 */
export async function toggleEventStatus(id, currentStatus) {
    try {
        const eventRef = ref(db, `${EVENTS_PATH}/${id}`);
        // Negate the current status
        await update(eventRef, { enabled: !currentStatus });
        return true;
    } catch (error) {
        console.error("Error toggling status:", error);
        throw error;
    }
}
