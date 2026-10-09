# Windows Security Scripts for CyberPatriot (PowerShell)

## Run All Windows Audits from One Script

Use [main.ps1](./main.ps1) as the launcher for the scripts in this directory. It runs the ten top-level read-only audits and writes separate logs and a CSV run summary to a timestamped folder under your Documents directory.

From an elevated Windows PowerShell session in the repository folder:

```powershell
# Preview the list of scripts without running any:
.\main.ps1 -Mode List

# Run audits (default; no Windows security settings changed):
.\main.ps1

# Include the extra sample user audit and detailed firewall rules:
.\main.ps1 -IncludeExampleAudit -ListFirewallRules

# Explicitly permit a Defender signature update and INTERACTIVE service review:
.\main.ps1 -Mode Full -AllowChanges

# DANGEROUS: automatically disable the targeted services with no per-service prompt:
.\main.ps1 -Mode Full -AllowChanges -AutoDisableServices
```

Full mode runs the two remaining top-level scripts: `defender_update.ps1` and `service_hardening.ps1`. The launcher intentionally **does not auto-run** the `Examples/` hardening examples or `Templates/` because they may change password, firewall, service, or antivirus settings that a competition image requires. Only the optional `Examples/Audit-LocalUsers.ps1` is supported as an additional read-only audit.

**Check the current CyberPatriot competition rules and the image's README before running any script.** Test changes in an authorized practice VM. The report files can expose local users, services and network information; do not publish them. A successful script exit does not prove the system is secure.

---

This directory contains unique PowerShell scripts designed to aid in auditing and reconnaissance during CyberPatriot competitions. **These scripts prioritize information gathering and verification over making direct system changes.**

**Disclaimer:** Always understand what a script does before running it, especially in a competition environment. Test scripts thoroughly in practice VMs. Use scripts to augment, not replace, manual investigation and understanding. **Prioritize actions based on the README, not just script output.**

## Scripting Philosophy for CyberPatriot

-   **Read-Only First:** Prioritize scripts that gather information without making changes.
-   **Targeted Information:** Scripts should collect specific, relevant security data (users, services, tasks, etc.).
-   **Baseline-Friendly Output:** Format output consistently (e.g., sorted lists) to make comparison with `diff` tools (like Meld) easier.
-   **Efficiency:** Automate repetitive checks to save time.
-   **Safety:** Avoid commands that could disrupt required services or violate competition rules.

## Available Scripts (Examples - Create/Update as needed)

-   **`Audit-UsersAndGroups.ps1`** (Placeholder - Create if missing)
    *   *Purpose:* Gathers information about local users (enabled status, password policies) and key group memberships (Administrators, Remote Desktop Users). Provides a quick overview of account status.
    *   *Output:* Formatted console output summarizing user accounts and group members.
-   **`Check-CommonPersistence.ps1`** (Placeholder - Create if missing)
    *   *Purpose:* Checks common persistence locations like Registry Run/RunOnce keys, enabled Scheduled Tasks (basic properties), and Startup folders. Highlights potentially suspicious entries for manual review.
    *   *Output:* Lists entries found in common persistence locations.
-   **`Audit-Services.ps1`** (Placeholder - Create if missing)
    *   *Purpose:* Lists running services and services set to auto-start, optionally filtering for non-Microsoft services or showing service executable paths. Helps identify potentially unnecessary or suspicious services.
    *   *Output:* Formatted list of services with relevant details (Name, DisplayName, Status, StartMode, PathName).
-   **`Get-SystemInfoAudit.ps1`** (Placeholder - Create if missing)
    *   *Purpose:* Gathers basic system information (OS version, hostname, uptime), checks firewall status, UAC status, and Defender status. Provides a quick system health check.
    *   *Output:* Summary of key system and security feature statuses.

## How to Use

1.  Transfer the desired script(s) to the target Windows VM (ensure transfer method is secure and permitted).
2.  Open **PowerShell as Administrator**.
3.  Temporarily adjust execution policy if needed (use the least permissive scope necessary):
    ```powershell
    # Example: Allow scripts for this PowerShell session only
    Set-ExecutionPolicy RemoteSigned -Scope Process -Force
    ```
4.  Navigate to the script's directory: `cd C:\Path\To\Scripts`
5.  Run the script: `.\ScriptName.ps1`
6.  **Carefully review the output.** Use the information to guide your manual investigation and hardening actions based on the competition README.

## Contribution

Develop new scripts focusing on:
-   **Information Gathering:** Checking specific security settings (e.g., audit policy status, specific registry keys related to security features), finding prohibited files, checking share permissions.
-   **Non-Destructive Checks:** Scripts should avoid making changes unless explicitly designed for a safe, reversible configuration check (clearly documented).
-   **Clarity and Comments:** Ensure scripts are well-commented, explaining each section's purpose.
-   **Uniqueness:** Tailor scripts for common CyberPatriot findings and avoid simply copying generic scripts found online.

---
*All scripts are unique and designed for Grissom JROTC CyberPatriot training. Always test thoroughly before competition use.*
