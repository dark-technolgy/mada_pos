# Advanced Rebranding & Cloud Infrastructure Plan

This plan expands the rebranding to include a full cloud ecosystem using Supabase and GitHub, featuring CI/CD, silent updates, and cloud backups.

## User Review Required

> [!IMPORTANT]
> **Name Confirmation:** Proceeding with **"Mada" (مدى)**.
> - **Internal Project Name:** `mada_pos`
> - **Display Name:** Mada Smart POS - مدى للمبيعات الذكية
>
> **Action Required from User:**
> 1. **GitHub:** Create a new repository on GitHub and provide the URL (e.g., `https://github.com/username/mada_pos.git`).
> 2. **Supabase:** Create a project and provide the **Project URL** and **Service Role Key** (needed for specific backend triggers) or **Anon Key**.
> 3. **Manual Approval Flow:** In Supabase Auth settings, you must **disable "Confirm Email"** and **enable "Confirm User"** (or I will implement a custom `is_approved` flag in a `profiles` table).

## Proposed Changes

### 1. Global Rebranding
- **Pubspec:** Rename `keenx_pos` to `mada_pos`.
- **Localization:** Update all strings to "Mada" / "مدى".
- **Assets:** Rename icons and splash screens.

### 2. Supabase Integration (Auth & Storage)
- **Supabase Auth:** Implement login/signup using `supabase_flutter`. Users will sign up, but access is restricted until an admin flips an `is_approved` flag in the `profiles` table.
- **Cloud Backup:** Modify `BackupService` to upload the SQLite `.db` file to a Supabase Storage bucket named `backups`.

### 3. CI/CD & GitHub Actions
- **Workflow:** Create `.github/workflows/supabase_deploy.yml`.
- **Auto-Sync:** On push to `main`, triggers a job to deploy Supabase Edge Functions or sync schema if necessary.
- **Silent Updates:** Implement `shorebird` (for Android) or a custom GitHub-release-based updater for Windows that checks for new versions in the background and prompts for a restart.

### 4. Technical Components
- **[NEW] `supabase_client.dart`**: Singleton for Supabase interaction.
- **[NEW] `cloud_backup_service.dart`**: Handles chunked uploads to Supabase Storage.
- **[NEW] `update_service.dart`**: Checks GitHub Releases for new Windows `.msix` or `.exe` installers.

## Verification Plan

### Automated Tests
- `flutter pub get` & `flutter test` to ensure naming integrity.
- GitHub Action mock run (via local `act` if available).

### Manual Verification
- **Rebranding:** Verify app name in Windows Task Manager and Android Launcher.
- **Auth:** Attempt login with an unapproved user (should fail) and an approved user (should pass).
- **Backup:** Trigger manual backup and verify file presence in Supabase Dashboard.
- **Update:** Simulate a version mismatch and verify the update prompt appears.
