# QR Barcode System Process Documentation

This document outlines the core processes and data structures of the QR Barcode System, a comprehensive solution for managing item registration, tracking, and validation through QR codes and barcodes. The system is designed to ensure accuracy, traceability, and efficient operation management.

## Table of Contents
1. [Database Structure](#database-structure)
2. [Item Registration Process](#item-registration-process)
3. [Scanning Process](#scanning-process)
4. [Data Flow](#data-flow)
5. [Error Handling](#error-handling)

## Database Structure

The database is designed to maintain data integrity and traceability throughout the scanning process. It uses a relational structure to track items, their configurations, scanning sessions, and individual scan results. Each table serves a specific purpose in the workflow, with clear relationships and constraints to ensure data consistency.

### Tables
- **items**: Master table containing core item information. This table serves as the central reference for all registered items in the system.
  * item_id: Unique identifier for each item
  * item_name: Name/model of the item
  * revision_number: Current revision of the item
  * total_codes: Number of codes required for this item
  * created_at: Timestamp of creation
  * updated_at: Last modification timestamp

- **item_codes**: Detailed code configurations for each item. Stores the specific requirements and validation rules for each code associated with an item.
  * code_id: Unique identifier for each code
  * item_id: Reference to parent item
  * code_type: "Counting" or "Non-Counting"
  * validation_rules: JSON containing format and validation specifications
  * sequence_format: Format specification for serial numbers (if Counting)
  * content_template: Expected content format (if Non-Counting)

- **scanning_sessions**: Records of scanning operations. Tracks each scanning session from start to finish, maintaining overall progress and status.
  * session_id: Unique session identifier
  * item_id: Reference to scanned item
  * po_number: Purchase order number
  * total_quantity: Target quantity for session
  * start_time: Session start timestamp
  * end_time: Session completion timestamp
  * status: Current session status

- **box_labels**: Box-level tracking data. Manages the grouping of scanned items into boxes, ensuring proper quantity and tracking.
  * box_id: Unique box identifier
  * session_id: Reference to parent session
  * article_label: Scanned article label data
  * quantity_target: Expected items per box
  * actual_quantity: Actually scanned items
  * status: Box completion status

- **individual_scans**: Individual item scan records. Stores detailed information about each scan operation, including validation results and timestamps.
  * scan_id: Unique scan identifier
  * session_id: Reference to scanning session
  * box_id: Reference to containing box
  * content: Scanned content
  * timestamp: Scan timestamp
  * status: Scan result (Good/No Good)
  * error_message: Details if scan failed

## Item Registration Process

The item registration process is a critical foundation of the system where engineers define the specifications and validation rules for each item. This process ensures that all subsequent scanning operations have proper validation criteria and maintain quality standards.

### Location: `lib/pages/register_item.dart`

### Detailed Steps:

1. **Initial Setup**
   The process begins with the engineer accessing the registration interface and initiating a new item registration.
   ```
   Process Initiation:
   - Engineer accesses Item Masterlist screen
   - Clicks "New Register" button
   - System initializes registration form
   - Loads validation rules and templates
   ```

2. **Basic Information Entry**
   Essential item details are captured to uniquely identify and track the item throughout its lifecycle.
   ```
   Required Information:
   a. Item Name:
      - Must be unique in system
      - Alphanumeric format
      - Maximum 50 characters
   
   b. Revision Number:
      - Format: REV-XX.YY
      - XX: Major revision (01-99)
      - YY: Minor revision (01-99)
   
   c. Number of Codes:
      - Minimum: 1
      - Maximum: 10
      - Determines how many codes must be scanned per item
   ```

3. **Code Configuration**
   Each code associated with the item is configured with specific validation rules and requirements.
   ```
   For Each Code:
   
   a. Category Selection:
      Counting Type:
      - Used for serial numbers
      - Requires sequence configuration
      - Enables duplicate prevention
      
      Non-Counting Type:
      - Fixed content verification
      - Pattern matching
      - Exact match requirements
   
   b. Label Content Definition:
      Format Specifications:
      - Prefix requirements
      - Character limitations
      - Special character rules
      - Length restrictions
   
   c. Validation Rules:
      - Format regex patterns
      - Required field markers
      - Conditional validations
      - Cross-reference checks
   ```

4. **Counting Code Setup**
   For items requiring serial number tracking, detailed sequence and validation rules are established.
   ```
   Serial Number Configuration:
   a. Format Definition:
      - Prefix specification
      - Numeric portion length
      - Suffix requirements
      - Total length validation
   
   b. Sequence Rules:
      - Starting number
      - Increment value
      - Range limitations
      - Skip patterns
   
   c. Validation Parameters:
      - Checksum requirements
      - Format enforcement
      - Range validations
      - Duplicate prevention rules
   ```

5. **Review and Confirmation**
   Final verification of all configurations before saving to the database.
   ```
   Final Review Process:
   a. Configuration Display:
      - Complete item details
      - All code configurations
      - Validation rules summary
   
   b. Verification Steps:
      - Format validation
      - Rule consistency check
      - Duplicate checking
   
   c. Database Storage:
      - Items table update
      - Item codes creation
      - Validation rules storage
   ```

## Scanning Process

The scanning process is the core operational workflow where operators scan and validate items according to the predefined configurations. This process ensures accurate data capture, real-time validation, and proper tracking of all scanned items.

### Technical Implementation Details

#### Key Components
- **Location:** `lib/pages/scan_item.dart`
- **State Management:** Uses `StatefulWidget` for dynamic updates
- **Database Integration:** Utilizes `DatabaseHelper` for data persistence
- **Input Handling:** Manages both manual and scanner input

#### Data Management
```
Key State Variables:
- _tableData: Stores all scan entries and results
- _usedContents: Tracks used contents for duplicate prevention
- _sessionId: Unique identifier for each scanning session
- _scanBuffer: Temporary storage for scanner input
```

#### Initialization Process
```
1. State Setup:
   - Load item configurations
   - Initialize counters and controllers
   - Set up focus nodes for input fields
   - Check for resume data from previous sessions

2. Configuration Loading:
   - Fetch item details from database
   - Load validation rules
   - Set up display content format
   - Configure sub-lot rules if applicable
```

### Location Flow: `operator_login.dart` → `article_label.dart` → `scan_item.dart`

### 1. Initial Setup
The setup phase establishes the context for the scanning session and loads necessary configurations.
```
Required Information Collection:

a. Item Name Scanning:
   - Barcode/QR scan of item identifier
   - System validates against items table
   - Loads item configuration and rules

b. P.O Number Scanning:
   - Purchase order barcode scan
   - Format validation
   - Cross-reference with system records

c. Quantity Specification:
   - Total items to be scanned
   - System calculates box quantities
   - Sets up progress tracking
```

### 2. Article Label Processing
Article labels provide batch-level information and must be validated before individual item scanning.
```
Validation Process:

a. Label Scanning:
   - Capture article label data
   - Parse label information
   - Extract key components

b. System Validations:
   Item Verification:
   - Match against scanned item name
   - Revision number confirmation
   - Configuration compatibility check

   PO Verification:
   - Match against entered PO number
   - Order quantity validation
   - Date range verification

   Data Extraction:
   - Lot number parsing
   - Quantity confirmation
   - Date information processing
```

### 3. Individual Item Scanning

#### Required Group-Based Scanning Functionality
The following requirements specify how the grouping functionality should work:

```
1. Group Activation:
   - Grouping functionality is always active for all items
   - Default group size is 1 scan per group
   - Applies to both counting and non-counting items

2. Group Counting:
   - Every N scans form one group, where N is the No. of Code value
   - Example: If No. of Code = 2, every 2 scans = 1 group
   - Groups are session-specific and never merge across sessions
   - Each session starts its own group numbering from 1
   - All quantity tracking should count completed groups as single units:
     * QTY per box
     * Inspection QTY
     * Good count
     * No Good count

3. Session and Box Management:
   - Each box represents a new scanning session
   - When QTY per box is reached:
     * Prompt user to scan new article label
     * Start new session with new box
     * Maintain all historical data from previous sessions:
       - Previous scans table data
       - Total inspection quantity
       - Cumulative Good/No Good counts
   - Continuous Counting Across Sessions:
     * Total inspection quantity accumulates across all sessions
     * Good/No Good counts continue incrementing across sessions
     * Previous scans table shows all historical scans
     * Group numbers restart from 1 in each new session
     * Box-specific quantities track only current box

4. Display Requirements:
   - Previous scans table must show clear session boundaries
   - Each session's groups should be visually distinct
   - Group numbers should restart for each session
   - Incomplete groups from previous sessions must remain incomplete
   - Complete groups maintain their original session grouping
   - Display running totals across all sessions for:
     * Total inspection quantity
     * Cumulative Good count
     * Cumulative No Good count

5. Database Storage:
   - Each scan record must include:
     * Session ID to track which session it belongs to
     * Group number relative to its session
     * Position within its group
     * Number of codes required for its group
     * Box ID for box-level tracking
   - Queries must:
     * Calculate group numbers within each session
     * Track cumulative counts across all sessions
     * Maintain box-specific quantities
     * Preserve session boundaries for display
```

#### Current Implementation

The following code snippets from `scan_item.dart` demonstrate the key components of the group-based scanning implementation:

1. Session Management and Group Tracking:
```dart
// Unique session ID for each scanning session
final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

// Track table data with group information
final List<Map<String, dynamic>> _tableData = [];
```

2. Group Calculation Logic:
```dart
// Calculate group information for non-counting items
Future<void> _validateContent(String value, int index) async {
  // ... other validation code ...

  if (_itemCategory == 'Non-Counting') {
    final items = await DatabaseHelper().getItems();
    final matchingItem = items.firstWhere(
      (item) => item['itemCode'] == itemName,
      orElse: () => {},
    );
    int noOfCodes = int.parse(matchingItem['codeCount'] ?? '1');
    
    // Calculate current group based on completed scans
    int previousCompletedGroups = (_tableData
            .where((row) => row['result']?.isNotEmpty == true)
            .length ~/
        noOfCodes);
    int currentGroup = previousCompletedGroups + 1;

    // Get position within current group (0-based)
    int positionInGroup = _tableData
            .where((row) => row['result']?.isNotEmpty == true)
            .length %
        noOfCodes;

    // Save to database with group information
    await DatabaseHelper().insertScanContent(
      operatorScanId,
      value,
      result,
      groupNumber: currentGroup,
      groupPosition: positionInGroup + 1,
      codesInGroup: noOfCodes,
      sessionId: _sessionId,
    );
  }
}
```

3. Quantity Tracking for Groups:
```dart
// Get the current group count for quantity calculations
int _getCurrentGroupCount() {
  if (_itemCategory == 'Non-Counting') {
    // For non-counting items, use the No. column to count groups with "Good" results
    return _tableData
      .where((item) => item['result'] == 'Good')
      .map((item) => item['rowNumber'] ?? 0)
      .toSet()
      .length;
  } else {
    // For counting items, count rows with "Good" results
    return _tableData
      .where((item) => item['result'] == 'Good')
      .map((item) => item['No.'] ?? item['rowNumber'])
      .toSet()
      .length;
  }
}
```

4. Historical Data Management:
```dart
// Update total inspection quantity considering groups
Future<void> _updateTotalInspectionQty() async {
  try {
    // Get historical completed groups for this item
    final historicalGroups = await DatabaseHelper().getTotalScansForItem(itemName);
    
    // Count current groups (not individual scans)
    Set<dynamic> uniqueGroups = _tableData
      .where((item) => item['result']?.isNotEmpty == true)
      .map((item) => item['groupNumber'] ?? item)
      .toSet();
    final currentGroups = uniqueGroups.length;
    
    setState(() {
      // Total inspection QTY is historical + current groups
      inspectionQtyController.text = 
        ((historicalGroups ?? 0) + currentGroups).toString();
    });
  } catch (e) {
    print('Error updating total inspection quantity: $e');
  }
}
```

5. Display Management for Groups:
```dart
// Build table rows with group information
List<DataRow> _buildTableRows() {
  return _tableData.asMap().entries.map((entry) {
    int index = entry.key;
    Map<String, dynamic> data = entry.value;
    
    // Calculate group information
    int noOfCodes = int.parse(matchingItem['codeCount'] ?? '1');
    int previousScans = _tableData
        .where((row) =>
            row['result']?.isNotEmpty == true &&
            _tableData.indexOf(row) < index)
        .length;
    
    // Show row number only for first scan in group
    bool isFirstInGroup = previousScans % noOfCodes == 0;
    
    return DataRow(
      cells: [
        DataCell(Text(isFirstInGroup ? 
          ((previousScans ~/ noOfCodes) + 1).toString() : '')),
        // ... other cells ...
      ],
    );
  }).toList();
}
```

6. Database Structure:
```sql
CREATE TABLE individual_scans (
  scan_id INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_scan_id INTEGER,
  content TEXT,
  result TEXT,
  group_number INTEGER,
  group_position INTEGER,
  codes_in_group INTEGER,
  session_id TEXT,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (operator_scan_id) REFERENCES operator_scans(id)
);
```

This implementation ensures that:
- Each scanning session maintains independent group numbering
- Groups are properly tracked and displayed
- Quantity calculations are based on completed groups
- Historical data preserves original grouping configurations
- Session boundaries are maintained for data integrity

#### Display Information
The scanning interface provides real-time feedback and progress information to operators.
```
Screen Layout:

a. Header Section:
   - Application title
   - Emergency stop button
   - Good/No Good counters with visual indicators

b. Item Information Panel:
   - Item Name and Details
   - Current PO Number
   - Active Lot Number
   - Revision Information
   - Content format display

c. Quantity Tracking Panel:
   - Total QTY (target)
   - QTY per box (current/target)
   - Inspection QTY (progress)

d. Scanning Status Area:
   - Expected Code Format
   - Last Scan Result
   - Error Messages
   - Validation Status

e. Progress Indicators:
   - Current Box Progress
   - Total Session Progress
   - Good/No Good Counts
   - Remaining Quantity

f. Historical Data Section:
   - Previous scans table
   - Cumulative counts
   - Session statistics
```

#### Scanning Process Flow
The core scanning operation includes multiple validation steps and real-time feedback mechanisms.
```
Detailed Scanning Procedure:

1. Input Processing:
   a. Scanner Input Handling:
      - Buffered input collection
      - Auto-submission on completion
      - Debounce protection
      - Focus management

   b. Manual Input Support:
      - Text field entry
      - Validation on submission
      - Error prevention

2. Validation Phase:
   a. Format Checking:
      - Pattern matching
      - Length validation
      - Character verification
      - Checksum validation

   b. Type-Specific Validation:
      Counting Items:
      - Serial number extraction
      - Sequence verification
      - Range validation
      - Duplicate checking
      - Sub-lot number conversion
      
      Non-Counting Items:
      - Content matching
      - Format compliance
      - Pattern verification
      - Required field checking
      - Group tracking

3. Real-time Processing:
   a. Status Updates:
      - Visual feedback (Green/Red)
      - Sound indicators
      - Error message display
      - Status message updates
      - Focus management for next scan

   b. Counter Management:
      - Good scan increment
      - Error tracking
      - Progress calculation
      - Completion percentage
      - Historical data updates

4. Box Management:
   a. Completion Handling:
      - Quantity verification
      - Final validation
      - Status update
      - Data persistence
      - Box completion alerts

   b. New Box Initialization:
      - Article label requirement
      - Counter reset
      - Status clear
      - Progress update
      - Focus management

5. Session Management:
   a. Progress Tracking:
      - Total completion monitoring
      - Box progress tracking
      - Quantity limit enforcement
      - Session status updates

   b. Emergency Handling:
      - Process suspension
      - Data preservation
      - Engineer authentication
      - Incident documentation
```

#### Error Prevention and Recovery
```
1. Input Validation:
   - Debounce mechanism for rapid scans
   - Format verification before processing
   - Duplicate prevention
   - Sequence validation

2. Error Handling:
   - Immediate visual feedback
   - Error message display
   - Sound alerts for issues
   - No Good result documentation
   - Recovery procedures

3. Data Integrity:
   - Transaction management
   - State preservation
   - Automatic backups
   - Recovery mechanisms
```

### Data Storage Flow
The system maintains data integrity through a structured storage process at multiple levels.
```
Data Management Process:

1. Individual Scan Processing:
   a. Data Capture:
      - Scan content
      - Timestamp
      - Status code
      - Error details

   b. Database Storage:
      - individual_scans record creation
      - Status update
      - Error logging
      - Relationship linking

2. Box Level Management:
   a. Completion Processing:
      - Quantity verification
      - Status update
      - box_labels record update
      - Relationship maintenance

3. Session Level Tracking:
   a. Progress Management:
      - Total progress calculation
      - Status updates
      - Completion tracking
      - Time management
```

## Error Handling

The error handling system ensures data accuracy and provides clear feedback for problem resolution. It includes comprehensive validation checks and emergency procedures for exceptional situations.

### Scan Validation
A multi-layered validation system ensures data accuracy and prevents common scanning errors.
```
Comprehensive Error Management:

1. Format Validation:
   a. Visual Indicators:
      - Red highlight for errors
      - Error message display
      - Status updates
      - Sound alerts

   b. Error Types:
      - Format mismatch
      - Invalid characters
      - Length errors
      - Checksum failures

2. Sequence Management:
   a. Serial Number Validation:
      - Order verification
      - Range checking
      - Duplicate detection
      - Format compliance

   b. Processing Rules:
      - Skip detection
      - Range validation
      - Pattern matching
      - Sequence tracking

3. Quantity Control:
   a. Box Level:
      - Quantity limits
      - Progress tracking
      - Overflow prevention
      - Underflow detection

   b. Session Level:
      - Total quantity monitoring
      - Progress validation
      - Completion verification
      - Limit enforcement
```

### Emergency Procedures
Procedures for handling unexpected situations or process interruptions.
```
Emergency Handling Process:

1. Process Suspension:
   a. Immediate Actions:
      - Scanning suspension
      - Data preservation
      - Status update
      - Alert generation

   b. System State:
      - Current progress saving
      - Transaction completion
      - Connection management
      - State preservation

2. Documentation Process:
   a. Authentication:
      - Engineer credentials
      - Access verification
      - Authorization check
      - Permission validation

   b. Record Creation:
      - Incident details
      - Timestamp recording
      - Status documentation
      - Resolution notes
```

This documentation provides a comprehensive guide to the core processes of item registration and scanning operations. Each section includes detailed explanations of the procedures, validations, and data management aspects to ensure accurate and efficient operation of the system. The structured approach to data management, validation, and error handling ensures reliability and traceability throughout the scanning process. 