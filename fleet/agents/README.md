# Fleet Osquery Agent Deployment

## ⚠️ Important Note

Fleet agent deployment is **less automated** than Velociraptor/Wazuh because Fleet requires an **enrollment secret** that must be obtained from the Fleet UI before installing agents.

## Workflow

1. **Admin** logs into Fleet UI → Gets enrollment secret
2. **Download** agent package from CyberBlue portal
3. **Install** osquery on endpoint
4. **Manually enter** the enrollment secret during setup
5. **Configure** Fleet server URL (pre-configured in package)
6. **Start** osquery service

## Difference from Other Agents

| Agent | Configuration | User Action Required |
|-------|---------------|---------------------|
| Velociraptor | CA cert (auto-extracted) | None - zero config ✅ |
| Wazuh | Manager IP only | None - zero config ✅ |
| Fleet | Server IP + Enrollment Secret | **Must get secret from Fleet UI** ⚠️ |

## Why This Limitation?

Fleet's enrollment secret is:
- Generated in Fleet UI
- Can be rotated for security
- Not stored in server config files
- Must be manually retrieved

## Ports Used

- **7007**: Fleet server (web UI + agent API)

## Package Contents

Each Fleet agent package includes:
- Osquery installer (.msi/.deb/.rpm/.pkg)
- `fleet-config.flags` - Pre-configured with server IP
- `INSTALL.txt` - Step-by-step instructions including how to get secret

## Future Enhancement

Could potentially:
- Add API to retrieve enrollment secret programmatically
- Pre-fill secret in config if admin provides it
- Auto-generate temporary enrollment secrets

For now, users must manually obtain the secret from Fleet UI.

