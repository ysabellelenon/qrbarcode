# Technical Requirements Document: QR Barcode System

## 1. Overview

**Project Name:** QR Barcode System  
**Platform:** Offline desktop application for Windows  
**Framework:** Flutter with support for Windows desktop apps  
**Purpose:** Develop an offline barcode and QR code management system for Engineers and Operators with a built-in local database.

---

## 2. System Architecture

### 2.1 Application Architecture
- **Frontend:**  
  - Developed using Flutter for a cross-platform UI with a focus on desktop support.  
  - Integration with native Windows APIs for enhanced desktop capabilities (e.g., file system access, hardware integration).  
- **Backend:**  
  - Local business logic implemented in Dart.  
  - Data persistence handled using SQLite.  
  - QR and barcode data validation logic built into the app.  
- **Database:**  
  - SQLite for local data storage (users, items, and scanned data).  
  - No dependency on external servers.  

---

## 3. Functional Requirements

### 3.1 Login System
- Role-based access:
  - **Engineer Role:** Full access to user, item, and database management.
  - **Operator Role:** Restricted access to scanning and inspection workflows.
- **Authentication:** 
  - Credentials stored locally in encrypted form.
  - Username: Employee ID.

### 3.2 User Management (Engineer Role)
- CRUD operations for users:
  - Add/Edit/Delete users.
  - Assign roles (Engineer or Operator).
- Form validations for required fields.
- Confirmation dialogs for destructive actions.

### 3.3 Item Management (Engineer Role)
- CRUD operations for items:
  - Add/Edit/Delete items in the masterlist.
  - Configure categories: Counting or Non-Counting.
  - Sub-lot number rules for Counting items.
- Validation logic:
  - Ensure unique item names and valid label content.
  - Support for data review before submission.

### 3.4 QR/Barcode Scanning (Operator Role)
- **Validation:**
  - Non-Counting: Validate against static label content.
  - Counting: Validate and increment unique serial numbers.
- **Error Handling:**
  - Highlight errors (e.g., wrong scan) in red.
  - Prevent progression until errors are resolved.
- **Inspection:**
  - Tally Good and No Good quantities.
  - Compare totals for validation.

### 3.5 Emergency Handling
- Emergency stop button:
  - Suspend current operations.
  - Require Engineer authentication to resume.
  - Record remarks for interruptions.

### 3.6 Database Management
- SQLite database for local data storage.
- Automated local backups:
  - Backup database file on a set schedule.
  - Manual export option for external storage.
- Restore functionality for database recovery.

---

## 4. Non-Functional Requirements

### 4.1 Usability
- Responsive desktop UI optimized for mouse and keyboard.
- Simple navigation for both Engineer and Operator roles.
- Intuitive error messages and validation prompts.

### 4.2 Performance
- Handle up to:
  - 5,000 items in the masterlist.
  - 1,000 scans per day without performance degradation.
- Low resource consumption suitable for mid-range Windows laptops.

### 4.3 Security
- Store sensitive data (passwords, QR/Barcode data) in encrypted form.
- Role-based access control to restrict unauthorized actions.
- Local database encryption for added security.

### 4.4 Offline Operation
- The application must operate entirely offline.
- No reliance on external servers or internet connectivity.

---

## 5. Technology Stack

### 5.1 Front-End
- **Framework:** Flutter (Windows Desktop)  
- **Language:** Dart  
- **UI Design Tools:** Flutter Material and Desktop-specific widgets

### 5.2 Back-End
- **Business Logic:** Dart  
- **Database:** SQLite via the `sqflite` Flutter package  
- **Encryption:** `encrypt` or `flutter_secure_storage` package for sensitive data  

### 5.3 QR/Barcode Scanning
- Integration with **Keyence HR-100 Scanner** via:
  - Flutter Desktop Channels for native API calls.
  - Keyboard emulation (scanner output as text input).

---

## 6. Development Workflow

### 6.1 Key Milestones
1. **Project Setup:**
   - Initialize Flutter project with Windows desktop support.
   - Configure SQLite and database schema.
2. **Core Features Development:**
   - Implement login system with role-based access.
   - Develop Engineer dashboard for user and item management.
   - Build Operator interface for scanning and validation workflows.
3. **Hardware Integration:**
   - Implement scanner support and validate hardware interactions.
4. **Database Features:**
   - Develop backup, restore, and export functionalities.
5. **Testing:**
   - Conduct unit, integration, and UI testing for all features.
   - Test performance with large datasets.
6. **Release:**
   - Package the application for Windows using Flutter desktop builds.

---

## 7. Technical Considerations

- **Database Storage Limits:**
  - SQLite should efficiently handle up to 50,000 records without performance degradation.
- **Desktop Optimization:**
  - Ensure seamless integration with Windows file system (e.g., save/export database files).
- **Scanner Compatibility:**
  - Validate the app with the Keyence HR-100 scanner for accurate QR/Barcode input.
- **Error Handling:**
  - Include robust error logging for database, UI, and hardware-related issues.

---

## 8. Deployment

### 8.1 Target Platform
- **OS:** Windows 10 and above (64-bit).  
- **Dependencies:**  
  - Flutter SDK configured for Windows builds.  
  - Pre-installed SQLite runtime libraries (packaged with the app).  

### 8.2 Distribution
- Deliverable: Executable `.exe` file with necessary dependencies bundled using tools like `MSIX` or `Inno Setup`.  

### 8.3 Installation
- Single installer for Windows:
  - Install app and local database setup.
  - Register dependencies for Flutter runtime.

---

## 9. Open Questions

1. Is there a need for export/import of data (e.g., CSV, JSON)?  
2. Should the app generate detailed daily/weekly reports?  
3. Are there additional hardware compatibility requirements for other scanners?  

---

## 10. References

- Flutter Documentation for Desktop: [Flutter Desktop Support](https://flutter.dev/desktop)  
- SQLite Documentation: [SQLite Official Site](https://www.sqlite.org/)  
- Keyence HR-100 Scanner Documentation (as applicable).  

---

Let me know if you’d like adjustments or additional sections in the TRD!