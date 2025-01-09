# QR Barcode System Process Documentation

## Table of Contents
1. [Dependencies](#dependencies)
2. [Database Structure](#database-structure)
3. [User Roles & Authentication](#user-roles--authentication)
4. [Engineer Processes](#engineer-processes)
5. [Operator Processes](#operator-processes)
6. [Data Flow](#data-flow)
7. [Error Handling](#error-handling)

## Dependencies

### Core Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.0.0  # Local database
  path: ^1.8.0     # File path handling
  path_provider: ^2.0.0  # Access to system directories
  pdf: ^3.8.0      # PDF generation
  file_picker: ^5.0.0  # File selection dialogs
  window_size: ^0.0.1  # Window management for desktop
```

### Database Setup
- Location: `lib/database_helper.dart`
- Initialization: During app startup in `main.dart`
- Tables:
  - users
  - items
  - item_codes
  - scanning_sessions
  - box_labels
  - individual_scans

## User Roles & Authentication

### Login Process
1. User enters credentials in `login_page.dart`
2. `DatabaseHelper` validates against `users` table
3. Routes to appropriate dashboard based on role:
   - Engineer → `engineer_login.dart`
   - Operator → `operator_login.dart`

## Engineer Processes

### 1. Item Registration
**Location:** `lib/pages/register_item.dart`

**Process Flow:**
1. Engineer clicks "New Register" in Item Masterlist
2. Fills basic item details:
   - Item Name
   - Revision Number
   - Number of Codes
3. For each code:
   - Selects category (Counting/Non-Counting)
   - Enters label content
4. If any code is "Counting":
   - Redirects to `sublot_config.dart`
   - Configures sub-lot rules and serial numbers
5. Reviews details in `review_item.dart`
6. On confirmation:
   - Data saved to `items` and `item_codes` tables
   - Returns to Item Masterlist

### 2. User Management
**Location:** `lib/pages/manage_accounts.dart`

**Process Flow:**
1. Create New User:
   - Navigate to Account Settings → New Account
   - Fill user details in `new_account.dart`
   - Data saved to `users` table
2. Edit User:
   - Select user in Manage Accounts
   - Modify details in `edit_user.dart`
   - Updates `users` table
3. Delete User:
   - Select users in list
   - Confirm deletion
   - Removes records from `users` table

## Operator Processes

### 1. Scanning Process
**Location:** `lib/pages/operator_login.dart` → `article_label.dart` → `scan_item.dart`

**Step-by-Step Flow:**

1. **Initial Input** (`operator_login.dart`)
   ```
   - Scan Item Name
   - Scan P.O Number
   - Enter Total Quantity
   ```

2. **Article Label Scanning** (`article_label.dart`)
   ```
   - Scan article label
   - System validates:
     - Item name matches
     - PO number matches
     - Extracts lot number and quantity
   ```

3. **Item Scanning** (`scan_item.dart`)
   ```
   Initial Display:
   - Shows item details (Item Name, PO Number, Lot Number)
   - Displays expected content format for scanning
   - Shows quantity targets:
     - Total Quantity Required
     - Quantity per Box
     - Current Box Progress
   
   Scanning Process:
   1. Operator scans QR/barcode on each item
      - System automatically validates scan format
      - For Counting items:
        * Validates serial number sequence
        * Prevents duplicate serial numbers
        * Shows error if wrong sequence detected
      - For Non-Counting items:
        * Validates exact match with registered content
   
   2. After each scan:
      - Status updates immediately (Good/No Good)
      - Good scans: Highlighted in green
      - Error scans: Highlighted in red with error message
      - Running totals update:
        * Good Count
        * No Good Count
        * Total Scanned
   
   3. Box Completion:
      - System alerts when box quantity is reached
      - Operator must click "Scan New Article Label"
      - Previous box data is saved and new box starts
   
   4. Session Progress:
      - Historical data table shows all scans
      - Progress bar indicates total completion
      - System prevents scanning beyond total quantity
   
   Outcomes:
   - Each scan is recorded in individual_scans table
   - Box completion updates box_labels table
   - Session data maintained in scanning_sessions table
   - Real-time validation prevents:
     * Duplicate scans
     * Out-of-sequence numbers
     * Incorrect formats
     * Quantity overruns
   ```

4. **Emergency Stop** (if needed)
   ```
   - Click Emergency Stop button
   - Enter Engineer credentials
   - Add remarks
   - System generates summary
   ```

### 2. Data Validation

#### Content Validation
**Location:** `lib/pages/scan_item.dart`

```dart
void _validateScan(String scannedContent) {
  // 1. Check format matches item configuration
  // 2. For Counting items:
  //    - Validate serial numbers
  //    - Track used numbers
  // 3. For Non-Counting:
  //    - Match exact content
}
```

#### Quantity Tracking
- Box Quantity: Tracked in `scan_item.dart`
- Total Quantity: Compared against initial input
- Historical Data: Fetched from `individual_scans` table

## Data Flow

### 1. Item Registration Flow
```
register_item.dart
    ↓
sublot_config.dart (if Counting)
    ↓
review_item.dart
    ↓
database_helper.dart (saves to items & item_codes tables)
```

### 2. Scanning Flow
```
operator_login.dart
    ↓ (saves to scanning_sessions table)
article_label.dart
    ↓ (saves to box_labels table)
scan_item.dart
    ↓ (saves to individual_scans table)
finished_item.dart or emergency_stop.dart
```

### 3. Data Relationships
```
scanning_sessions
    ↓
box_labels (linked by sessionId)
    ↓
individual_scans (linked by sessionId)
```

## Error Handling

### 1. Scan Validation Errors
**Location:** `lib/pages/scan_item.dart`
- Invalid format: Highlighted in red
- Duplicate scans: Prevented and notified
- Quantity mismatch: Alerts when box/total quantity reached

### 2. Database Errors
**Location:** `lib/database_helper.dart`
- Connection errors: Shown via SnackBar
- Transaction failures: Rolled back with error message
- Data integrity: Foreign key constraints enforced

### 3. Emergency Procedures
**Location:** `lib/pages/emergency_stop.dart`
- Immediate process suspension
- Engineer authentication required
- Remarks logging
- PDF summary generation

## Date/Time Handling

### Display Formats
- Created at timestamps: ISO 8601 format
- Display format: YYYY-MM-DD HH:mm:ss
- Stored in database as TEXT in UTC

### Source Locations
1. Scan timestamps: Generated in `scan_item.dart`
2. Article label dates: Extracted in `article_label.dart`
3. Emergency stop time: Recorded in `emergency_stop.dart`

## PDF Generation
**Location:** `lib/utils/pdf_generator.dart`

Generates reports for:
1. Emergency stops
2. Completed scanning sessions
3. Historical data

## Window Management
**Location:** `lib/main.dart`

```dart
void main() {
  // Set minimum window size
  setWindowMinSize(const Size(1280, 720));
  
  // Set default window size
  setWindowFrame(Rect.fromLTWH(0, 0, 1280, 720));
}
```

This documentation covers the main processes and data flows in the system. Each component is designed to work offline and maintain data integrity through the local SQLite database. 