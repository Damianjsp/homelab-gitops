# Security Notes - IMPORTANT

## Secrets Management Policy

⚠️ **NEVER commit plaintext credentials or secrets to this repository!**

### What NOT to Do

- ❌ NEVER commit passwords, tokens, or API keys
- ❌ NEVER commit private keys or certificates
- ❌ NEVER commit database credentials
- ❌ NEVER commit credential markdown files (*.md)
- ❌ NEVER commit shell scripts with credentials

### What TO Do

1. **For Kubernetes Secrets**: Use sealed-secrets
   - Encrypt credentials with kubeseal
   - Only `*-sealed-secret.yml` files are safe to commit
   - Plaintext secrets are NEVER committed

2. **For Configuration**: Use environment variables
   - Store in `.env` (git-ignored)
   - Reference via deployment env vars

3. **For Local Development**: Use `.env` or `.env.local`
   - Both are in `.gitignore`
   - Load locally only, never commit

## Git Protection

### Automatic Protection

These patterns are in `.gitignore`:
```
*-secret.yml           # Except sealed variants
*-CREDENTIALS.md       # No credential docs
*-credentials.md
*.creds
.credentials
.env
.env.local
POSTGRESQL-SETUP-*.md  # Setup docs may contain sensitive info
setup-*.sh             # Setup scripts may contain sensitive info
```

### Manual Review Before Commit

Before pushing:
```bash
git diff --cached  # Review all staged changes
git status         # Check for accidental untracked files
```

## Current Status

✅ Plaintext credentials have been removed from git history using `git-filter-repo`
✅ `.gitignore` updated to prevent future leaks
✅ `.gitignore` is committed and will protect all future commits

## If You Accidentally Commit Secrets

1. **Immediately rotate the compromised secret** (password, token, etc.)
2. Run `git filter-repo` to remove from history
3. Force push: `git push origin main --force`
4. Alert your security team if any critical secrets were exposed

## PostgreSQL Credentials

The PostgreSQL password `12345qwe` is stored as:
- ✅ Kubernetes Secret in cluster (encrypted at rest)
- ❌ NOT in git repository
- ⏳ Will be sealed with sealed-secrets (encrypted further)

## References

- [Sealed-Secrets Documentation](https://github.com/getsops/sealed-secrets)
- [Git-Filter-Repo Guide](https://github.com/newren/git-filter-repo)
- [OWASP Secret Management](https://owasp.org/www-community/Secrets_Store)
