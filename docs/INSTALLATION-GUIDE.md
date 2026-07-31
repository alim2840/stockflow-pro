# StockFlow Pro — Installation Guide (Windows)

**For:** end users and IT staff · **Product:** StockFlow Pro 1.0.0 · **Publisher:** Mindtune Innovations
**Developer:** Muhammad Ali — Accounts & Finance Expert, MBA (Finance) — alim2840@gmail.com

## 1. Requirements
- Windows 10 (64-bit, 1809+) or Windows 11
- An internet connection (the app connects to your company's cloud server)
- Your **company server address** from your administrator, e.g. `https://stock.yourcompany.com`
- **No Node.js, VS Code, Python, or terminal is required.**

## 2. Install (recommended: Setup EXE)
1. Double-click **`StockFlow-Pro-Setup-x64.exe`**.
2. If Windows SmartScreen appears ("Windows protected your PC"), click
   **More info → Run anyway**. This happens because the installer is not yet
   digitally signed — see §6. Verify the file first if you wish (§5).
3. Choose Install for **all users** (needs admin rights) or **current user only**.
4. Accept the license, keep the default folder, and finish.
5. The installer automatically adds the **Microsoft WebView2 Runtime** if missing,
   creates a **Start Menu** entry ("StockFlow Pro"), an optional **desktop
   shortcut**, and registers the app in **Settings → Installed Apps**.

**MSI alternative:** `StockFlow-Pro-x64.msi` supports managed deployment
(Intune, SCCM, GPO): `msiexec /i StockFlow-Pro-x64.msi /qn`.

**Portable:** unzip `StockFlow-Pro-Portable-x64.zip` and run
`StockFlow Pro.exe` (Windows 11 has WebView2 preinstalled; on older Windows 10
run the Setup EXE once instead, or install WebView2 from Microsoft).

## 3. First launch
1. Open **Start Menu → StockFlow Pro**.
2. The app checks your internet connection, then asks once for your
   **company server address**. Type the address from your administrator and
   click **Connect**. It is remembered on this computer.
3. The **sign-in screen** appears. Log in with the email and password your
   administrator invited you with. Use **Forgot password?** to reset by email.

If your company hasn't set up its server yet, your administrator should follow
`ADMIN-DEPLOYMENT-GUIDE.md` first.

## 4. Uninstall / reinstall / upgrade
- **Uninstall:** Settings → Installed Apps → StockFlow Pro → Uninstall.
  Business data is **not** affected — it lives in your company's cloud database.
- **Reinstall / upgrade:** run the new Setup EXE over the old version. Your
  server address and window preferences are kept; cloud data is untouched.

## 5. Verify your download (recommended)
PowerShell:
```powershell
Get-FileHash .\StockFlow-Pro-Setup-x64.exe -Algorithm SHA256
```
Compare the value with `SHA256SUMS.txt` from the same release folder.

## 6. Code signing (for IT)
This release is **not digitally signed**; SmartScreen warnings are expected.
To sign future builds:
1. Obtain an OV/EV Authenticode certificate (Sectigo, DigiCert, GlobalSign) or
   use **Azure Trusted Signing**.
2. On the build machine: `signtool sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /f company.pfx /p <password> StockFlow-Pro-Setup-x64.exe`
   — or in CI, add the certificate as the `WINDOWS_CERTIFICATE` /
   `WINDOWS_CERTIFICATE_PASSWORD` GitHub secrets referenced in
   `.github/workflows/windows-release.yml`.
3. EV certificates remove SmartScreen warnings immediately; OV certificates
   build reputation over downloads.

## 7. Troubleshooting
| Symptom | Fix |
|---|---|
| "Server could not be reached" on the connect screen | Check internet; confirm the address with your admin; the app retries automatically every 5 s. |
| Blank window after login | Your server address may point to the wrong site — use **Use a different server** on the offline screen. |
| SmartScreen blocks the installer | §2 step 2, and verify the checksum (§5). |
| App opens off-screen after monitor change | Delete `%APPDATA%\com.mindtune.stockflowpro\.window-state.json`. |
