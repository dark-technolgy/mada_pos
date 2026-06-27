# Mada Smart POS

Mada Smart POS is a Flutter desktop point-of-sale and sales management system focused on Arabic, Kurdish, and English business workflows. The project combines local-first data storage with cloud-ready features like Supabase authentication, cloud backups, and automated updates.

## Core Capabilities

- Desktop-first POS flow with held invoices, barcode entry, discounts, and printable invoices.
- Inventory, products, categories, warehouses, customers, suppliers, debts, expenses, and reports.
- Multi-language interface: Arabic, English, and Kurdish.
- Multi-currency support with base-currency normalization for dashboards and reports.
- Cloud Integration: Supabase Auth (with manual approval), Storage for backups, and GitHub-based silent updates.
- Local Drift database with audit logging and backup/restore tools.

## Architecture Summary

- UI: Flutter with Material 3.
- State management: Riverpod.
- Navigation: GoRouter.
- Persistence: Drift + SQLite.
- Cloud: Supabase (Auth, Storage).
- Reporting/printing: pdf, printing, fl_chart.
- Desktop shell: window_manager.

## Development Setup

Prerequisites:

- Flutter SDK compatible with Dart 3.11.
- Supabase project URL and Anon Key.

Install dependencies:

```bash
flutter pub get
```

Generate Drift and other code if needed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run the desktop app:

```bash
flutter run -d windows
```

## Default Access

On a fresh database, the app seeds a default administrator account:

- Username: admin
- Password: admin123

## Data and Backups

- Local backups are stored in the user's home directory under Mada_Backups.
- Cloud backups are securely uploaded to Supabase Storage.

## Windows Distribution

Build the release app, user manuals (AR/EN/KU), portable ZIP, and setup installer:

```powershell
.\scripts\build_windows_installer.ps1
```

Outputs land in `dist/`:

| File | Description |
|------|-------------|
| `Mada_POS_Setup_1.0.0.exe` | Windows installer |
| `Mada_POS_Portable_1.0.0.zip` | Portable folder |
| `Mada_POS_User_Manual_AR.pdf` | Arabic user guide |

## Logging & support

- Application errors are logged to `%LOCALAPPDATA%\Mada_POS\logs\`.
- Open the log folder from **About → Open logs**.
