# Product Requirements Document: QR Barcode System

## 1. Overview

**Product Name:** QR Barcode System  
**Purpose:** Develop an offline desktop application to manage, validate, and store QR and barcode data locally for assembly line processes.  
**Target Users:** Engineers (Admins) and Operators (Assembly Line Leaders).  
**Platform:** Windows desktop application with a built-in local database.  

---

## 2. Objectives

1. Enable offline management and validation of QR/barcode data.  
2. Simplify item and user account management with a responsive desktop interface.  
3. Ensure data integrity and backup locally for recovery during system interruptions.

---

## 3. Functional Requirements

### 3.1 User Management
- **Login**
  - Separate login interfaces for Engineers and Operators.
  - Username: Employee ID.
  - Password: Configurable by Engineers.
  - Feedback for incorrect credentials.
- **Engineer Account Settings**
  - Manage user accounts:
    - View user list with details (First Name, Last Name, Section, Line No., Role).
    - Add new users: Input details including username (ID) and password.
    - Edit user details.
    - Delete users with confirmation dialog.
  - Roles:
    - **Engineer:** Full access to user and item management.
    - **Operator:** Restricted access to scanning and inspection processes.

### 3.2 Item Management
- **Item Masterlist**
  - Tabular display of registered items with details:
    - Item Name, Revision Number, Category, Label Content, Results (Good/No Good).
  - Search functionality to filter items.
  - Actions:
    - **Revise Item:** Update details of existing items.
    - **Register New Item:** Add new items with required fields.
- **Item Registration**
  - Input fields:
    - Item Name.
    - Revision Number.
    - Number of Codes.
    - Category (Counting/Non-Counting).
    - Label Content (based on company standards).
  - Sub-lot configuration for counting items:
    - Enable/disable sub-lot rules.
    - Specify the number of serial numbers.
  - Review details before finalizing the registration process.

### 3.3 Barcode Scanning and Validation
- **Operator Scanning**
  - Scan and validate QR/Barcode labels.
  - For non-counting labels: Validate against static predefined contents.
  - For counting labels: Validate unique serial numbers and increment as necessary.
  - Incorrect article scans:
    - Highlight errors in red.
    - Prevent progression until corrected.
- **Inspection**
  - Tally quantities:
    - Good vs. No Good items.
    - Total quantity and inspection quantity.
  - Track box-wise quantities for completeness before moving to the next step.

### 3.4 Emergency Handling
- Emergency stop functionality:
  - Interrupt operations due to unforeseen circumstances.
  - Require Engineer/Operator credentials to resume.
  - Provide remarks for stoppage reasons.

### 3.5 Local Database Management
- Use a local database (e.g., SQLite):
  - Store user accounts, items, and scanned data.
  - Provide backup and recovery options.
- Backup functionality:
  - Manual export of database to local storage.
  - Scheduled local backups to ensure data safety.

---

## 4. Non-Functional Requirements

- **Usability**
  - Desktop-friendly interface with minimal learning curve.
  - Clear and logical navigation for different roles.
- **Performance**
  - Handle up to 5,000 items and 1,000 scans per day without performance degradation.
- **Data Security**
  - Password-protected user accounts.
  - Local encryption for sensitive data in the database.
- **Offline Functionality**
  - Operates without internet connection.
  - Sync or export capabilities when connected to external systems (optional).

---

## 5. Design and Navigation Flow

1. **Login Screen**  
   - Engineer Login → Engineer Dashboard (Account Management & Masterlist).  
   - Operator Login → Scanning Interface.  

2. **Engineer Workflow**  
   - Manage accounts (add, edit, delete users).  
   - Register or revise items in the masterlist.  
   - Backup and restore the local database as needed.  

3. **Operator Workflow**  
   - Scan Purchase Orders (PO) and Item Names.  
   - Validate QR/Barcode labels against database records.  
   - Tally inspection results and quantities.  

4. **Error Handling**  
   - Display errors for invalid scans.  
   - Provide options to retry or escalate to Engineer.  

---

## 6. Technical Specifications

- **Front-End:**  
  - Framework: Electron.js (for modern Windows desktop apps) or .NET WPF (native Windows app).
- **Back-End:**  
  - Language: Python with SQLite for local database management or .NET for all-in-one development.
- **Local Database:**  
  - SQLite with automated backups and manual export capabilities.
- **Hardware:**  
  - Compatible with Keyence HR-100 scanner for QR/Barcode input.  

---

## 7. Success Metrics

1. Achieve seamless offline operation with zero reliance on external servers.  
2. Ensure 99.9% data accuracy in QR/Barcode validation and tallying.  
3. Provide an intuitive experience for Engineers and Operators, with minimal training required.

---

## 8. Constraints and Assumptions

- The application will only run on Windows desktop systems.
- All data will be stored locally, with no external server dependencies.
- The Keyence HR-100 scanner is the primary input device for QR/Barcode scanning.
- Engineer users are responsible for managing data backups.

---

## 9. Open Questions

1. Is there a requirement for data export to external systems (e.g., CSV, JSON)?  
2. Should the system include reporting features (e.g., daily activity logs)?  
3. Are there any hardware or software compatibility requirements for the local database?  

---