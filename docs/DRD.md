Here’s the Database Requirements Document (DRD) for the QR Barcode System:

# Database Requirements Document: QR Barcode System

## 1. Overview

**Database Type:** SQLite  
**Purpose:**  
To manage and store all data locally, including user accounts, item details, scanned QR/barcode records, and operational logs. The database must operate offline and ensure data integrity, security, and recoverability.

---

## 2. Database Objectives

1. Provide efficient storage and retrieval of user, item, and scan data.  
2. Enable secure, role-based access control.  
3. Support data validation for QR and barcode contents.  
4. Facilitate backups and recovery processes.  

---

## 3. Data Requirements

### 3.1 Core Entities

#### **Users**
- **Purpose:** Manage system users with roles for Engineers and Operators.
- **Fields:**
  - `user_id` (Primary Key, Integer, Auto-increment)
  - `username` (Text, Unique, Employee ID format)
  - `password` (Text, Encrypted)
  - `first_name` (Text)
  - `last_name` (Text)
  - `role` (Text, Enum: `Engineer`, `Operator`)
  - `section` (Text)
  - `line_no` (Text)
  - `created_at` (DateTime, Auto-generated)

#### **Items**
- **Purpose:** Store details of registered items with QR/barcode information.
- **Fields:**
  - `item_id` (Primary Key, Integer, Auto-increment)
  - `item_name` (Text, Unique)
  - `revision_no` (Integer)
  - `category` (Text, Enum: `Counting`, `Non-Counting`)
  - `label_content` (Text)
  - `no_of_codes` (Integer)
  - `created_at` (DateTime, Auto-generated)
  - `updated_at` (DateTime, Auto-generated)

#### **Scanned Data**
- **Purpose:** Log and validate scanned QR/barcode information.
- **Fields:**
  - `scan_id` (Primary Key, Integer, Auto-increment)
  - `item_id` (Foreign Key, References `Items.item_id`)
  - `scanned_content` (Text)
  - `status` (Text, Enum: `Good`, `No Good`)
  - `scan_time` (DateTime, Auto-generated)
  - `operator_id` (Foreign Key, References `Users.user_id`)

#### **Settings**
- **Purpose:** Store application settings and configurations.
- **Fields:**
  - `setting_id` (Primary Key, Integer, Auto-increment)
  - `key` (Text, Unique)
  - `value` (Text)

#### **Logs**
- **Purpose:** Record critical application events and errors.
- **Fields:**
  - `log_id` (Primary Key, Integer, Auto-increment)
  - `log_type` (Text, Enum: `Error`, `Action`)
  - `description` (Text)
  - `timestamp` (DateTime, Auto-generated)

---

## 4. Database Schema

### Tables and Relationships
1. **Users**  
   - One-to-many relationship with Scanned Data (`user_id → operator_id`).  
2. **Items**  
   - One-to-many relationship with Scanned Data (`item_id → item_id`).  
3. **Scanned Data**  
   - Linked to both Users and Items tables for validation and tracking.  
4. **Settings**  
   - A key-value store for application-wide configurations.  

---

## 5. Functional Requirements

1. **User Authentication**
   - Validate login credentials against the `Users` table.
   - Restrict access based on roles (Engineer or Operator).
2. **Item Registration**
   - Insert/update items in the `Items` table.
   - Ensure unique `item_name` and validate revision numbers.
3. **Scan Validation**
   - Insert records into the `Scanned Data` table.
   - Check the `label_content` for match with `Items` table.
   - Track scan status (`Good` or `No Good`) for each record.
4. **Backup and Restore**
   - Enable export of the entire SQLite database to a local file.
   - Support manual import of the database for recovery.
5. **Error Logging**
   - Automatically insert error details into the `Logs` table.

---

## 6. Non-Functional Requirements

- **Storage Capacity:**  
  - Handle up to 50,000 records in total without performance degradation.  
- **Performance:**  
  - Query execution time under 1 second for typical operations (login, scan validation).  
- **Security:**  
  - Encrypt sensitive data (e.g., passwords).  
  - Restrict direct access to the SQLite database file using application logic.  
- **Integrity:**  
  - Enforce foreign key constraints to maintain data consistency.  
- **Backup:**  
  - Local file backup with minimal user intervention.

---

## 7. Entity Relationship Diagram (ERD)

### Overview:
- **Users** → `user_id` links to `operator_id` in **Scanned Data**.
- **Items** → `item_id` links to `item_id` in **Scanned Data**.
- **Settings** is a standalone table.
- **Logs** is a standalone table.

```plaintext
+-----------+           +---------+           +--------------+
|   Users   |           |  Items  |           |  Logs        |
|-----------|           |---------|           |--------------|
| user_id   |<--------->| item_id |<--------->| log_id        |
| username  |           | name    |           | log_type      |
| password  |           | content |           | description   |
+-----------+           +---------+           | timestamp     |
                                             +--------------+
```

## 8. Database Access Patterns

1.	Login and Authentication
   - Query the Users table to validate credentials.
2.	Item Lookup
   - Search Items table by item_name or label_content.
3.	Scan Logging
   - Insert scan data into Scanned Data with references to Items and Users.
4.	Reporting
   - Summarize Scanned Data by item or operator for quality assurance.

## 9. Open Questions

1.	Should additional encryption layers be added for the SQLite file (e.g., password-protected backups)?
2.	Are there requirements for integrating this database with external systems in the future?
3.	Should historical data (e.g., older than one year) be archived or retained indefinitely?