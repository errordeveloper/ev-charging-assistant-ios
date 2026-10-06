# Security and privacy boundaries

- Local BLE does not need an account or a backend. Request Bluetooth permission only when the user starts discovery. Explain the selected accessory and unsupported/unknown states.
- Vehicle diagnostic access is scoped to a reviewed read-only allowlist. Adapter configuration commands are separate from vehicle operations. No arbitrary diagnostic console, coding/flash/clear-DTC endpoints, or model-to-CAN path.
- Bind each session to the explicitly selected vehicle/profile/adapter; names alone are not trusted identity. Review documented BLE pairing/encryption rather than assuming a radio link is secure.
- OAuth/provider/model keys live on the backend. User session/refresh credentials on iOS use Keychain. Scope tokens narrowly, revoke on unlink/delete, and use provider-authenticated flows rather than collecting OEM passwords.
- No production credential is needed for routine CI or replay. Signing and lab credentials live in protected trusted environments. External PRs do not receive them.
- Minimize stored SoC history and trip data; do not send continuous raw BLE frames or VIN to the model. Retention and deletion must be selected and tested before beta.
- Logs and agent artifacts must redact credentials, precise routes, VIN, advertising identifiers, exact Bluetooth IDs, and user-owned device names. Use rotating scoped IDs where possible.
- Treat provider/model outputs as untrusted; validate schemas, ranges, units, observation times, user scope, and tool permissions before use. A response cannot redefine the tool allowlist.
- The initial app advises only. Route handoff is visible user action. Payments, booking, remote locking, charging changes, and account changes require separate product scope and authorization.
- Review provider/data licenses, privacy policy, Apple privacy disclosures, and actual shipped behavior together before distribution. No open-source license or public visibility is chosen by the bootstrap.

Report suspected issues privately to the repository owner before publishing captures or user data. Establish a formal reporting address when the product reaches beta.
