importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: '',
    appId: '1:1037891053876:web:81c2e3621b353288261d61',
    messagingSenderId: '1037891053876',
    projectId: 'ehop-backend',
    authDomain: 'ehop-backend.firebaseapp.com',
    storageBucket: 'ehop-backend.firebasestorage.app',
    measurementId: 'G-34F13PTVEZ',
});
// Necessary to receive background messages:
const messaging = firebase.messaging();

// Optional:
messaging.onBackgroundMessage((m) => {
  console.log("onBackgroundMessage", m);
});
