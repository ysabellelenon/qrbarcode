PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT,
        middleName TEXT,
        lastName TEXT,
        section TEXT,
        lineNo TEXT,
        username TEXT UNIQUE,
        password TEXT
      );
INSERT INTO users VALUES(1,'Engineer',NULL,'User','Engineering','Admin','engineer','password123');
INSERT INTO users VALUES(2,'Operator',NULL,'User','Operations','Assembly','operator','password123');
CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemCode TEXT,
        revision TEXT,
        codeCount TEXT,
        category TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        lastUpdated DATETIME,
        isActive INTEGER DEFAULT 1
      );
INSERT INTO items VALUES(1,'MX38002S0021428','1','1',NULL,'2025-02-10 12:53:55',NULL,1);
INSERT INTO items VALUES(2,'MX55J04C0019348','1','2','Non-Counting','2025-02-10 23:16:37','2025-02-11T08:57:59.768527',1);
CREATE TABLE item_codes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemId INTEGER,
        category TEXT,
        content TEXT,
        hasSubLot INTEGER NOT NULL DEFAULT 0,
        serialCount TEXT,
        FOREIGN KEY (itemId) REFERENCES items (id) ON DELETE CASCADE
      );
INSERT INTO item_codes VALUES(1,1,'Counting','015 ',0,'4');
INSERT INTO item_codes VALUES(6,2,'Non-Counting','K1PY04Y00317_-',0,'0');
INSERT INTO item_codes VALUES(7,2,'Non-Counting','K1PY04Y00317_-',0,'0');
CREATE TABLE scanning_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT,
        poNo TEXT,
        totalQty INTEGER,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      );
INSERT INTO scanning_sessions VALUES(99,'MX55J04C0019348','1024382484',20,'2025-02-11T20:55:35.285030');
INSERT INTO scanning_sessions VALUES(100,'MX38002S0021428','1024445269',20,'2025-02-11T20:56:09.894188');
INSERT INTO scanning_sessions VALUES(101,'MX38002S0021428','1024445269',20,'2025-02-11T20:56:38.929426');
CREATE TABLE box_labels(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER,
        labelNumber TEXT,
        lotNumber TEXT,
        qtyPerBox TEXT,
        content TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sessionId) REFERENCES scanning_sessions (id) ON DELETE CASCADE
      );
INSERT INTO box_labels VALUES(95,99,'P001X0244132MX55J04C0019348               R-Pb        PH60       102438248400030001/003   250201-08','250201-08','60','K1PY04Y00317_-250201-08','2025-02-11T20:55:41.947529');
INSERT INTO box_labels VALUES(96,100,'P001X0283212MX38002S0021428               R-Pb        PH60       102444526900030001/003   241126-02','241126-02','60','015 24112602','2025-02-11T20:56:14.539514');
INSERT INTO box_labels VALUES(97,101,'P001X0283212MX38002S0021428               R-Pb        PH60       102444526900030001/003   241126-02','241126-02','60','015 24112602','2025-02-11T20:56:45.763940');
CREATE TABLE individual_scans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER,
        content TEXT,
        result TEXT,
        groupNumber INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sessionId) REFERENCES scanning_sessions (id) ON DELETE CASCADE
      );
INSERT INTO individual_scans VALUES(441,99,'K1PY04Y00317_-250201-08','Good',1,'2025-02-11T20:55:48.397283');
INSERT INTO individual_scans VALUES(442,99,'K1PY04Y00317_-250201-08','Good',1,'2025-02-11T20:55:48.408475');
INSERT INTO individual_scans VALUES(443,100,'015 24112620010','Good',1,'2025-02-11T20:56:18.876060');
INSERT INTO individual_scans VALUES(444,100,'015 24112620010','No Good',2,'2025-02-11T20:56:21.124773');
INSERT INTO individual_scans VALUES(445,100,'015 24112620011','Good',3,'2025-02-11T20:56:25.197938');
INSERT INTO individual_scans VALUES(446,100,'015 24112620012','Good',4,'2025-02-11T20:56:28.630412');
INSERT INTO individual_scans VALUES(447,100,'015 24112620013','Good',5,'2025-02-11T20:56:32.592299');
CREATE TABLE current_user(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER
      );
INSERT INTO current_user VALUES(78,2);
CREATE TABLE scans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operatorScanId INTEGER,
        content TEXT,
        result TEXT,
        groupNumber INTEGER,
        groupPosition INTEGER,
        codesInGroup INTEGER,
        sessionId TEXT,
        timestamp TEXT,
        FOREIGN KEY (operatorScanId) REFERENCES operator_scans (id) ON DELETE CASCADE
      );
DELETE FROM sqlite_sequence;
INSERT INTO sqlite_sequence VALUES('users',2);
INSERT INTO sqlite_sequence VALUES('current_user',78);
INSERT INTO sqlite_sequence VALUES('items',2);
INSERT INTO sqlite_sequence VALUES('item_codes',7);
INSERT INTO sqlite_sequence VALUES('scanning_sessions',101);
INSERT INTO sqlite_sequence VALUES('box_labels',97);
INSERT INTO sqlite_sequence VALUES('individual_scans',447);
COMMIT;
