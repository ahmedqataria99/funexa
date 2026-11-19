# Permissions and Security

## Security model
The application uses a local role-based access control model backed by SQLite tables in the main database. The core session logic is implemented in `SecurityLocalDataSource`.

## Roles and permissions
The source includes tables for:
- `roles`
- `permissions`
- `role_permissions`
- `users`
- `user_scopes`
- `audit_logs`

The session object stores:
- `SecurityUser`
- `SecurityRole`
- permission set
- scope list

## Access checks
The session layer enforces:
- `can(permission)` for permission-based checks
- `canAccess(ScopeType type, String resourceId)` for data-scope checks
- admin override via a system admin role

## Session and setup rules
- `ensureInitialAdmin()` initializes app setup state.
- `setupInitialAdmin()` creates the system administrator if none exists.
- `initialAdminSetupRequired()` blocks access until setup is completed.
- `login()` verifies hashed credentials and records audit events.

## Security limitations
- This is a local desktop ERP, so authentication is not backed by OAuth or external identity providers.
- Security is enforced at the data-source boundary but not fully formalized into a higher application-level policy engine for every feature.
- Some workflows depend on UI-level gating as well as repository-level permission checks, which makes the model partially distributed.

## Audit trail
The audit mechanism writes to `audit_logs` for key success and failure events, including login attempts and setup actions.

## Risk assessment
The project has a workable local access control design but remains a legacy desktop app with a large number of modules and a non-uniform permission enforcement pattern. That means a future audit should verify each feature repository for the same strict permission checks.
