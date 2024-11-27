# QR Barcode System

## Overview
The **QR Barcode System** is an offline Windows-based desktop application designed for Engineers and Operators to manage, validate, and scan QR and barcode data efficiently. Built using Flutter, it ensures seamless functionality without reliance on internet connectivity.

## Features
- **User Authentication**: Role-based access for Engineers and Operators.
- **Item Management**: Add, edit, and delete items with category and label configurations.
- **Barcode/QR Scanning**: Validate scanned data in real-time with clear error handling.
- **Local Database**: Store all data locally using SQLite, with backup and restore functionality.
- **Emergency Handling**: Suspend operations and resume with Engineer authorization.

## Technologies Used
- **Framework**: [Flutter](https://flutter.dev/) (Windows Desktop)
- **Database**: SQLite (Local in-app database)
- **Languages**: Dart for both frontend and backend logic
- **Hardware Integration**: Compatible with Keyence HR-100 Scanner

## Installation

### Prerequisites
1. **Operating System**: Windows 10 or higher (64-bit).
2. **Flutter SDK**: Install Flutter with Windows desktop support.  
   [Get Flutter](https://flutter.dev/docs/get-started/install)
3. **SQLite**: No separate installation required; bundled with the app.

### Steps
1. Clone this repository:
   ```bash
   git clone https://github.com/your-repo/qr-barcode-system.git
   ```
2. Navigate to the project folder:
   ```bash
   cd qr-barcode-system
   ```
3. Build the application:
   ```bash
   flutter build windows
   ```
4. Run the executable:
   - Navigate to the `build/windows/runner/Release/` folder.
   - Run the generated `.exe` file.

## Usage

### Engineer Role
1. Login using Engineer credentials.
2. Access the Dashboard to:
   - Manage user accounts.
   - Add or revise items in the Item Masterlist.
   - Perform database backups or restores.
3. Log out when finished.

### Operator Role
1. Login using Operator credentials.
2. Access the Scanning Interface to:
   - Scan and validate QR/barcode data.
   - Monitor scan results (Good, No Good).
3. Use the emergency stop when necessary.

## Screenshots
Add screenshots here (e.g., Login screen, Dashboard, Scanning interface).

## File Structure
```
qr-barcode-system/
├── lib/
│   ├── main.dart           # Entry point of the application
│   ├── screens/            # UI screens (Login, Dashboard, Scanning)
│   ├── widgets/            # Reusable UI components
│   ├── services/           # Database and business logic
│   └── models/             # Data models (User, Item, Scan)
├── assets/
│   ├── images/             # App images and icons
│   └── fonts/              # Custom fonts
├── test/                   # Unit and widget tests
├── pubspec.yaml            # Project dependencies
└── README.md              # Project documentation
```

## Backup and Restore

### Backup Database
1. Navigate to the Engineer Dashboard → Database Management.
2. Click Backup Now to save the database locally.

### Restore Database
1. Navigate to the Engineer Dashboard → Database Management.
2. Click Restore Database and select a backup file.

## Contributing
We welcome contributions! Please follow these steps:
1. Fork the repository.
2. Create a new branch:
   ```bash
   git checkout -b feature-name
   ```
3. Make your changes and commit them:
   ```bash
   git commit -m "Add new feature"
   ```
4. Push to your branch:
   ```bash
   git push origin feature-name
   ```
5. Submit a pull request.

## Known Issues
- Error Handling: In rare cases, database restore might require restarting the app.
- Scanner Compatibility: Tested only with Keyence HR-100. Other scanners may need additional setup.

## Future Enhancements
- Add multi-language support.
- Enable report generation for scanned data.
- Implement data import/export in CSV format.

## License
This project is licensed under the MIT License. See the LICENSE file for details.

## Contact
For questions or support, contact:
- Developer: [Your Name]
- Email: your.email@example.com
- GitHub: Your GitHub Profile