# PostgreSQL Secret Management

This directory uses **Sealed Secrets** to securely manage PostgreSQL credentials in Git.

## Overview

- **Sealed Secrets Controller**: Encrypts secrets at rest in the repository
- **Encryption**: Only decryptable on your specific Kubernetes cluster
- **Storage**: Plaintext secrets are stored in `.gitignore`, sealed versions in Git

## Deployment Order (Important!)

⚠️ **IMPORTANT**: Deploy sealed-secrets controller BEFORE generating sealed secrets!

1. **Phase 1**: Deploy sealed-secrets controller via ArgoCD
2. **Phase 2**: Generate and seal PostgreSQL credentials
3. **Phase 3**: Deploy PostgreSQL with sealed secrets

## Setup Instructions

### Step 1: Install Prerequisites

1. **Install kubeseal CLI** (locally on your machine):

```bash
# macOS
brew install kubeseal

# Or download from: https://github.com/getsops/sealed-secrets/releases
```

2. **Wait for sealed-secrets controller** to be deployed by ArgoCD:

```bash
# Check if controller is running
kubectl get pods -n sealed-secrets
kubectl logs -n sealed-secrets deployment/sealed-secrets-controller
```

The controller must be running before you can seal secrets!

### Step 2: Deploy Sealed-Secrets Controller

The sealed-secrets controller is managed by ArgoCD in `applications/core-services/sealed-secrets.yml`

When ArgoCD syncs, it will automatically deploy:

- Sealed-secrets controller deployment
- RBAC permissions
- Service for kubeseal to connect to

**Verify deployment**:

```bash
kubectl get deployment -n sealed-secrets
kubectl get sealedsecrets --all-namespaces
```

### Step 3: Generate and Seal PostgreSQL Credentials

⚠️ **Only proceed after sealed-secrets controller is running!**

Verify the controller is ready:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets
```

#### Create plaintext secret (locally, never commit)

```bash
kubectl create secret generic postgresql-credentials \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=YOUR_SECURE_PASSWORD_HERE \
  --from-literal=POSTGRES_DB=homelab \
  --namespace=postgresql \
  --dry-run=client -o yaml > /tmp/pg-secret.yml
```

#### Seal the secret

Only encrypts with your cluster's key (safe to commit!):

```bash
kubeseal \
  --namespace postgresql \
  --format yaml \
  < /tmp/pg-secret.yml \
  > infrastructure/base/postgresql/postgresql-sealed-secret.yml
```

#### Verify sealed secret was created

```bash
cat infrastructure/base/postgresql/postgresql-sealed-secret.yml
```

You should see `encryptedData` with encrypted values - this is what gets committed to Git.

#### Clean up the plaintext secret

```bash
rm /tmp/pg-secret.yml
```

#### Deploy PostgreSQL with sealed secret

Once sealed, commit the changes:

```bash
git add infrastructure/base/postgresql/postgresql-sealed-secret.yml
git commit -m "Add sealed PostgreSQL credentials"
git push
```

ArgoCD will automatically deploy PostgreSQL with the sealed secret.

### Safe to Commit to Git

Safe to commit:
- ✅ `postgresql-sealed-secret.yml` (encrypted)
- ✅ `postgresql-configmap.yml` (no secrets)
- ✅ `postgresql-deployment.yml` (references sealed secret)

Never commit:

- ❌ Plaintext secret files
- ❌ `/tmp/` directory with unencrypted secrets

### How ArgoCD Uses It

1. ArgoCD deploys `postgresql-sealed-secret.yml` to the cluster
2. Sealed Secrets controller automatically decrypts it into a normal `Secret`
3. PostgreSQL deployment references the decrypted secret
4. Only your cluster can decrypt it (encryption key never leaves the cluster)

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

#### Error: `cannot get sealed secret service: services "sealed-secrets-controller" not found`

**Cause**: You're trying to seal secrets before the controller is deployed.

**Solution**:

1. Wait for sealed-secrets controller to be deployed by ArgoCD
2. Verify it's running:

   ```bash
   kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets
   ```

3. Then try sealing again

#### Error: `"Failed to unseal secret"`

**Cause**: Secret was sealed for a different cluster or namespace.

**Solution**:
- Ensure sealed-secrets controller is running: `kubectl get pods -n sealed-secrets`
- Verify the secret was sealed for the correct namespace
- Check controller logs: `kubectl logs -n sealed-secrets deployment/sealed-secrets-controller`

#### Error: `"kubeseal command not found"`

**Solution**:
```bash
# macOS
brew install kubeseal

# Or manually download from:
# https://github.com/getsops/sealed-secrets/releases
```

#### How to verify sealed secret works

```bash
# Check if secret was unsealed correctly
kubectl get secret postgresql-credentials -n postgresql -o yaml
```

You should see the `Secret` resource with decoded data.

#### Need to see the actual password (for debugging)

```bash
kubectl get secret postgresql-credentials \
  -n postgresql \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

## References

- [Sealed Secrets GitHub](https://github.com/getsops/sealed-secrets)
- [ArgoCD + Sealed Secrets Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)
