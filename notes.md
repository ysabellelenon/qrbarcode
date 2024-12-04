## Moving `users.db` to Your Flutter Project Directory

To move your `users.db` file from its current location to your Flutter project directory, follow the steps below. This guide covers **using Terminal** on macOS.

### Current Location of `users.db`

Your database file is currently located at: /Users/ysabellelenon/Library/Containers/com.example.qrbarcode/Data/Documents

### Steps to Move `users.db` to Your Flutter Project

1. **Open Terminal.**

2. **Run the Following Commands:**

   ```bash
   # Navigate to the current directory of users.db
   cd /Users/ysabellelenon/Library/Containers/com.example.qrbarcode/Data/Documents/
   
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