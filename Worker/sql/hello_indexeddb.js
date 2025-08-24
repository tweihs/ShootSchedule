let db;

window.onload = function() {
    initDB();
};

function initDB() {
    const request = indexedDB.open("HelloDB", 1);

    request.onerror = function(event) {
        console.error("Database error:", event.target.error);
    };

    request.onupgradeneeded = function(event) {
        db = event.target.result;
        const objectStore = db.createObjectStore("messages", { keyPath: "id", autoIncrement: true });
        objectStore.createIndex("content", "content", { unique: false });

        // Load and process CSV file
        loadCSV();
    };

    request.onsuccess = function(event) {
        db = event.target.result;
        fetchMessages(); // Fetch messages after DB initialization or when visiting the page later
    };
}

function loadCSV() {
    fetch('../Geocoded_Combined_Shoot_Schedule_2024.csv')
        .then(response => response.text())
        .then(text => {
            const data = csvToArray(text);
            insertDataIntoDB(data);
        })
        .catch(error => console.error('Error loading the CSV file:', error));
}

function csvToArray(str, delimiter = ",") {
    str = str.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    const headers = str.slice(0, str.indexOf("\n")).split(delimiter);
    const rows = str.slice(str.indexOf("\n") + 1).split("\n");

    return rows.map(row => {
        const values = row.split(delimiter);
        return { content: values[0].trim() };  // Assuming you want the first column only
    });
}

function insertDataIntoDB(data) {
    const transaction = db.transaction(["messages"], "readwrite");
    const objectStore = transaction.objectStore("messages");

    data.forEach(item => {
        objectStore.add(item);
    });

    transaction.oncomplete = function() {
        console.log("All data from CSV inserted into database!");
        fetchMessages();  // Fetch all data once all data has been inserted
    };

    transaction.onerror = function(event) {
        console.error("Transaction error:", event.target.error);
    };
}

function fetchMessages() {
    const transaction = db.transaction(["messages"], "readonly");
    const objectStore = transaction.objectStore("messages");
    const request = objectStore.openCursor();
    const results = [];

    request.onsuccess = function(event) {
        let cursor = event.target.result;
        if (cursor) {
            results.push(cursor.value);
            cursor.continue();
        } else {
            console.log("All data fetched from the database:", results);
            updateTable(results);
        }
    };

    request.onerror = function(event) {
        console.error("Error fetching messages:", event.target.error);
    };
}

function updateTable(data) {
    const tbody = document.getElementById('resultsTable').getElementsByTagName('tbody')[0];
    tbody.innerHTML = ''; // Clear existing rows

    data.forEach(item => {
        let tr = "<tr>";
        tr += `<td>${item.content}</td>`;
        tr += "</tr>";
        tbody.innerHTML += tr;
    });

    if (data.length === 0) {
        tbody.innerHTML = '<tr><td>No data found</td></tr>';
    }
}
