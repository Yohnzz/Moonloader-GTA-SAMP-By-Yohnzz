import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getDatabase, ref, onValue, set, push, remove, update } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-database.js';

// IMPORTANT: Replace this config with your actual Firebase Project Configuration!
// Steps:
// 1. Go to https://console.firebase.google.com/
// 2. Create or open your project.
// 3. Go to Project Settings (Gear icon) -> General.
// 4. Scroll down to "Your apps", register a web app if not done yet.
// 5. Copy the firebaseConfig object below.
// 6. Go to "Realtime Database" in sidebar, create database, set rules to true for testing: 
//    { "rules": { ".read": "true", ".write": "true" } }
const firebaseConfig = {
    apiKey: "AIzaSyCnjUCaA98tFjSYu04JPJEogNSglZ7s0Tg",
    authDomain: "moonloader-event.firebaseapp.com",
    databaseURL: "https://moonloader-event-default-rtdb.asia-southeast1.firebasedatabase.app",
    projectId: "moonloader-event",
    storageBucket: "moonloader-event.firebasestorage.app",
    messagingSenderId: "343499765150",
    appId: "1:343499765150:web:18e0a5e3114ac8d20bd28f",
    measurementId: "G-W2Y2YHR4RV"
};

// Initialize Firebase App
const app = initializeApp(firebaseConfig);

// Initialize Realtime Database
const db = getDatabase(app);

// Export instances and modular functions to be used across the app
export { db, ref, onValue, set, push, remove, update };
