## Database Directory

/Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents/users.db

## Moving `users.db` to Your Flutter Project Directory

To move your `users.db` file from its current location to your Flutter project directory, follow the steps below. This guide covers **using Terminal** on macOS.

### Current Location of `users.db`

Your database file is currently located at: /Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents

### Steps to Move `users.db` to Your Flutter Project

1. **Open Terminal.**

2. **Run the Following Commands:**

   ```bash
   # Navigate to the current directory of users.db
   cd /Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents/
   
   # Create destination directories if they don't exist yet
   mkdir -p /Users/ysabellelenon/Desktop/qrbarcode/assets/databases/
   
   # Move the users.db file to the Flutter project
   mv users.db /Users/ysabellelenon/Desktop/qrbarcode/assets/databases/
   ```

#### Update `pubspec.yaml` to Include the Database as an Asset

To ensure Flutter recognizes the `users.db` file, you need to declare it in your `pubspec.yaml`.

```yaml
flutter:
  assets:
    - assets/databases/users.db
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
rm "/Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents/databases/users.db"
rm "/Users/rickylenon/Library/Containers/com.jae.qrbarcode/Data/Documents/databases/users.db"

# Copy the database to the project directory
rm users.db && cp "/Users/ysabellelenon/Library/Containers/com.jae.qrbarcode/Data/Documents/databases/users.db" users.db
rm users.db && cp "/Users/rickylenon/Library/Containers/com.jae.qrbarcode/Data/Documents/databases/users.db" users.db

# For Windows (Command Prompt): Copy runtime database to project root
rm users.db 2>nul
copy "%LOCALAPPDATA%\QRBarcode\databases\users.db" users.db

# For Windows (Command Prompt): Delete/Reset runtime database
del "%LOCALAPPDATA%\QRBarcode\databases\users.db" 2>nul

# For Windows (PowerShell): Copy runtime database to project root
Remove-Item -Path "users.db" -ErrorAction SilentlyContinue
Copy-Item -Path "$env:LOCALAPPDATA\QRBarcode\databases\users.db" -Destination "users.db"

# For Windows (PowerShell): Delete/Reset runtime database
Remove-Item -Path "$env:LOCALAPPDATA\QRBarcode\databases\users.db" -ErrorAction SilentlyContinue
```