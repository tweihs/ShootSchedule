const firebaseConfig = {
  apiKey: "AIzaSyAhiTL1-1EJflGJ8_l_9-CLWLR2_IZOO0k",
  authDomain: "shootsdb.com",
  projectId: "shootsdb-11bb7",
  storageBucket: "shootsdb-11bb7.firebasestorage.app",
  messagingSenderId: "1068585945321",
  appId: "1:1068585945321:web:38f1bbdad0fd0240b2c878",
  measurementId: "G-Q5086JYN36"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

if (window.location.hostname === "localhost") {
  firebase.auth().useEmulator("http://localhost:8080");
}

const auth = firebase.auth();
