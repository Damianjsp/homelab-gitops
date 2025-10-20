# PostgreSQL Secret Management

This directory uses **Sealed Secrets** to securely manage PostgreSQL credentials in Git.

## Overview

- **Sealed Secrets Controller**: Encrypts secrets at rest in the repository
- **Encryption**: Only decryptable on your specific Kubernetes cluster
- **Storage**: Plaintext secrets are stored in `.gitignore`, sealed versions in Git

## Setup Instructions

### Prerequisites

1. Sealed Secrets controller must be installed (handled by ArgoCD)
2. `kubeseal` CLI tool installed locally

```bash
# Install kubeseal (macOS)
brew install kubeseal

# Or download from: https://github.com/getsops/sealed-secrets/releases
```

### Generating PostgreSQL Secrets

1. **Create a plaintext secret (locally, never commit)**:

```bash
kubectl create secret generic postgresql-credentials \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=YOUR_SECURE_PASSWORD_HERE \
  --from-literal=POSTGRES_DB=homelab \
  --namespace=postgresql \
  --dry-run=client -o yaml > /tmp/pg-secret.yml
```

2. **Seal the secret** (only encrypts with your cluster's key):

```bash
kubeseal \
  --namespace postgresql \
  --format yaml \
  < /tmp/pg-secret.yml \
  > infrastructure/base/postgresql/postgresql-sealed-secret.yml
```

3. **Verify** the sealed secret was created:

```bash
cat infrastructure/base/postgresql/postgresql-sealed-secret.yml
```

4. **Clean up** the plaintext secret:

```bash
rm /tmp/pg-secret.yml
```

5. **Update** `postgresql-secret.yml` with a note to use sealed-secret instead (optional - you can delete it):

```bash
rm infrastructure/base/postgresql/postgresql-secret.yml
```

### Committing to Git

Safe to commit:
- ✅ `postgresql-sealed-secret.yml` (encrypted)
- ✅ `postgresql-configmap.yml` (no secrets)
- ✅ `postgresql-deployment.yml` (references sealed secret)

Never commit:
- ❌ Plaintext `postgresql-secret.yml`
- ❌ Plaintext secret files

### How ArgoCD Uses It

1. ArgoCD deploys `postgresql-sealed-secret.yml` to the cluster
2. Sealed Secrets controller decrypts it into a normal `Secret`
3. PostgreSQL deployment uses the decrypted secret
4. Only your cluster can decrypt it

### Updating Secrets

To change the PostgreSQL password:

1. Repeat the secret generation steps above with the new password
2. The new sealed secret will be encrypted with your cluster's key
3. Commit and push to git
4. ArgoCD will automatically update the deployment

### Backup

**Important**: Keep your sealed-secrets encryption key safe!

```bash
# Backup the sealing key (store securely)
kubectl get secret -n sealed-secrets -o yaml | \
  kubectl neat > sealed-secrets-backup.yaml
```

### Troubleshooting

**"Failed to unseal secret"**
- Ensure sealed-secrets controller is running: `kubectl get pods -n sealed-secrets`
- Verify the secret was sealed for the correct namespace

**"kubeseal command not found"**
- Install kubeseal: `brew install kubeseal`

**Need to decrypt a sealed secret?**
```bash
kubectl get sealedsecret postgresql-credentials \
  -n postgresql \
  -o jsonpath='{.status.observedGeneration}' && \
kubectl get secret postgresql-credentials \
  -n postgresql \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

## References

- [Sealed Secrets GitHub](https://github.com/getsops/sealed-secrets)
- [ArgoCD + Sealed Secrets Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)
