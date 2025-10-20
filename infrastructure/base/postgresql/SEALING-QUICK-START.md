# Sealed Secrets Quick Start

## TL;DR - The Workflow

### Phase 1: Deploy Controller (Do This First!)

```bash
# Just push to git - ArgoCD handles deployment
git push

# Wait for sealed-secrets controller
kubectl wait --for=condition=available --timeout=300s \
  deployment/sealed-secrets-controller -n sealed-secrets
```

### Phase 2: Generate and Seal Credentials

Once controller is running:

```bash
# 1. Create plaintext secret
kubectl create secret generic postgresql-credentials \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=MySecurePassword123! \
  --from-literal=POSTGRES_DB=homelab \
  --namespace=postgresql \
  --dry-run=client -o yaml > /tmp/secret.yml

# 2. Seal it
kubeseal --namespace postgresql < /tmp/secret.yml > postgresql-sealed-secret.yml

# 3. Clean up plaintext
rm /tmp/secret.yml
```

### Phase 3: Commit and Deploy

```bash
# Sealed secret is safe to commit!
git add postgresql-sealed-secret.yml
git commit -m "Add sealed PostgreSQL credentials"
git push

# ArgoCD deploys everything automatically
```

## Quick Checks

```bash
# Is sealed-secrets controller ready?
kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets

# Did sealing work?
cat postgresql-sealed-secret.yml

# Is PostgreSQL getting the credentials?
kubectl get secret postgresql-credentials -n postgresql -o yaml
```

## Common Issues

| Issue | Solution |
|-------|----------|
| `services "sealed-secrets-controller" not found` | Wait for controller to deploy: `kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets` |
| `kubeseal command not found` | Install: `brew install kubeseal` |
| Secret won't unseal | Check namespace matches: `kubeseal --namespace postgresql` |

## One-Liner Verification

```bash
# All in one: verify controller, seal secret, and check
kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets && \
kubeseal --namespace postgresql < /tmp/secret.yml > postgresql-sealed-secret.yml && \
echo "✅ Secret sealed successfully!"
```

For full documentation, see [README-SECRETS.md](README-SECRETS.md)
