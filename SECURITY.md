# Security

Do not include credentials, account IDs, personal paths, real quota screenshots,
or unredacted logs in public issues. Use synthetic fixtures to describe a bug.

For a suspected credential exposure, revoke or rotate the credential using the
official provider before discussing reproduction steps. Use GitHub's private
vulnerability reporting feature if it is enabled for this repository; otherwise
open a minimal issue asking for a private contact without disclosing the issue.

The application never asks for a provider token, password, or macOS password.
It does not bypass Keychain, workspace-trust dialogs, or operating-system security.

Downloaded builds are ad-hoc signed unless their release notes explicitly state
otherwise. Ad-hoc signing is not Developer ID signing or Apple notarization.
