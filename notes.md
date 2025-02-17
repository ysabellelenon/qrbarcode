## Database Directory

/Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents/qrbarcode.db

## Moving `qrbarcode.db` to Your Flutter Project Directory

To move your `qrbarcode.db` file from its current location to your Flutter project directory, follow the steps below. This guide covers **using Terminal** on macOS.

### Current Location of `qrbarcode.db`

Your database file is currently located at: /Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents

### Steps to Move `qrbarcode.db` to Your Flutter Project

1. **Open Terminal.**

2. **Run the Following Commands:**

   ```bash
   # Navigate to the current directory of qrbarcode.db
   cd /Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents/
   
   # Create destination directories if they don't exist yet
   mkdir -p /Users/ysabellelenon/Desktop/qrbarcode/assets/databases/
   
   # Move the qrbarcode.db file to the Flutter project
   mv qrbarcode.db /Users/ysabellelenon/Desktop/qrbarcode/assets/databases/
   ```

#### Update `pubspec.yaml` to Include the Database as an Asset

To ensure Flutter recognizes the `qrbarcode.db` file, you need to declare it in your `pubspec.yaml`.

```yaml
flutter:
  assets:
    - assets/databases/qrbarcode.db
```

> **Note:** Ensure proper indentation (two spaces) as YAML is indentation-sensitive.

After updating `pubspec.yaml`, run:

```bash
flutter pub get
```

#### Rebuild Your Flutter Project

After moving the file and updating configurations, rebuild your project to apply the changes.

```bash
flutter clean
flutter pub get
flutter run -d macos
```


# Test Data
```
Counting
ITEM NAME
MX49A04S0023608

PO
1023487999

Label Content
K1PY02YY0016

ARTICLE LABEL
P001X0304084MX49A04S0023608 R-Pb PH05 102348799900030001/001 240525-12

STATIC TEXT DISPLAY NA "CONTENT" (LABEL CONTENT + LOT NUMBRER)
K1PY02YY0016_240525-12
K1PY02YY0016_240525-13
K1PY02YY0016_240525-14
K1PY02YY0016_240525-15
K1PY02YY0016_240525-16
K1PY02YY0016_240525-17

P001X0304084MX49A04S0023608 R-Pb YL05 102348799900030001/001 240525-12

Non-Counting
ITEM NAME
MX30A04S0023601

PO
1023487999

ARTICLE LABEL
P001X0304084MX30A04S0023601 R-Pb YL03 102348799900030001/001 1808311-06k

STATIC TEXT DISPLAY NA "CONTENT" (LABEL CONTENT + LOT NUMBRER)
K1ZP02AL1234_1808311-06k

Counting with Sub-Lot Number Rules
ITEM NAME
MX38002S0021427

PO
1023487999

K1HY02YY0012

ARTICLE LABEL
P001X0304084MX38002S0021427 R-Pb HH03 102348799900030001/001 240528-20

STATIC TEXT DISPLAY NA "CONTENT" (LABEL CONTENT + LOT NUMBRER)
K1HY02YY0012_240528A
```


# Debug and View the database in Finder:
```bash
# Remove the database from the project directory
rm "/Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents/databases/qrbarcode.db"
rm "/Users/rickylenon/Library/Containers/com.jae.qrbarcode/Data/Documents/databases/qrbarcode.db"

# Copy the database to the project directory
rm qrbarcode.db && cp "/Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents/databases/qrbarcode.db" qrbarcode.db
rm qrbarcode.db && cp "/Users/rickylenon/Library/Containers/com.jae.qrbarcode/Data/Documents/databases/qrbarcode.db" qrbarcode.db

# For Windows (Command Prompt): Copy runtime database to project root
rm qrbarcode.db 2>nul
copy "%LOCALAPPDATA%\QRBarcode\databases\qrbarcode.db" qrbarcode.db

# For Windows (Command Prompt): Delete/Reset runtime database
del "%LOCALAPPDATA%\QRBarcode\databases\qrbarcode.db" 2>nul

# For Windows (PowerShell): Copy runtime database to project root
Remove-Item -Path "qrbarcode.db" -ErrorAction SilentlyContinue
Copy-Item -Path "$env:LOCALAPPDATA\QRBarcode\databases\qrbarcode.db" -Destination "qrbarcode.db"

# For Windows (PowerShell): Delete/Reset runtime database
Remove-Item -Path "$env:LOCALAPPDATA\QRBarcode\databases\qrbarcode.db" -ErrorAction SilentlyContinue


sqlite3 "/Users/rickylenon/Library/Containers/com.jae.qrbarcode/Data/Documents/QRBarcode/databases/qrbarcode.db" ".tables" | cat
sqlite3 "qrbarcode.db" ".tables" | cat
sqlite3 "/Users/rickylenon/Library/Containers/com.jae.qrbarcode/Data/Documents/QRBarcode/databases/qrbarcode.db" "SELECT * FROM license_info;" | cat
sqlite3 "qrbarcode.db" "SELECT * FROM license_info;" | cat
```