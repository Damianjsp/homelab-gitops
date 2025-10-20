# PostgreSQL Access Methods

## Dual Service Architecture

PostgreSQL is exposed through two services:
- **Internal Service** (`postgresql`): ClusterIP for internal cluster communication
- **External Service** (`postgresql-external`): LoadBalancer for local network access

Both services route to the same PostgreSQL pod for seamless access.

## External Access (From Local Network)

**Service**: `postgresql-external`
**Address**: `192.168.79.30:5432`
**User**: `postgres`
**Password**: `12345qwe`
**Database**: `homelab`

### Connection Examples

#### Using psql

```bash
psql -h 192.168.79.30 -U postgres -d homelab
```

#### Using connection string

```bash
postgresql://postgres:12345qwe@192.168.79.30:5432/homelab
```

#### Using Python

```python
import psycopg2

conn = psycopg2.connect(
    host="192.168.79.30",
    port=5432,
    user="postgres",
    password="12345qwe",
    database="homelab"
)
```

#### Using Node.js

```javascript
const { Client } = require('pg');

const client = new Client({
  host: '192.168.79.30',
  port: 5432,
  user: 'postgres',
  password: '12345qwe',
  database: 'homelab',
});
```

---

## Internal Cluster Access

**Service**: `postgresql` (ClusterIP)
**Address**: `postgresql.postgresql.svc.cluster.local:5432`
**User**: `postgres`
**Password**: `12345qwe`
**Database**: `homelab`

### Why Use Internal Service?

- ✅ Efficient DNS resolution within cluster
- ✅ No MetalLB overhead for internal communication
- ✅ Applications inside pods connect directly via ClusterIP
- ✅ Recommended for all in-cluster applications

### Connection Examples

#### From within a pod

```bash
kubectl exec -it deployment/postgresql -n postgresql -- \
  psql -U postgres -d homelab
```

#### Using port-forward (if needed)

```bash
kubectl port-forward svc/postgresql -n postgresql 5432:5432
psql -h localhost -U postgres -d homelab
```

---

## Network Architecture

```
Your Local Machine (192.168.x.x)
         ↓
    MetalLB LoadBalancer Service
    (192.168.79.30:5432)
         ↓
    Kubernetes Service (postgresql.postgresql.svc.cluster.local)
         ↓
    PostgreSQL Pod (10.42.1.178:5432)
         ↓
    Storage: /opt/postgresql-data on pi5-02
```

---

## Service Details

### Internal Service (ClusterIP)
- **Name**: `postgresql`
- **Type**: ClusterIP
- **Cluster IP**: 10.43.144.127
- **Port**: 5432
- **Use Case**: In-cluster applications

### External Service (LoadBalancer)
- **Name**: `postgresql-external`
- **Type**: LoadBalancer (with MetalLB)
- **External IP**: 192.168.79.30
- **Port**: 5432
- **NodePort**: 32023
- **Use Case**: External network access

### Deployment Details
- **Namespace**: postgresql
- **Deployment**: postgresql (1 replica)
- **Node**: pi5-02 (pinned via nodeSelector)
- **Storage**: /opt/postgresql-data on pi5-02 (50Gi)

## Kubernetes Details

```bash
# Check service
kubectl get svc -n postgresql postgresql

# Check endpoints
kubectl get endpoints -n postgresql postgresql

# Check pod
kubectl get pod -n postgresql

# Check logs
kubectl logs -n postgresql deployment/postgresql

# Get service info
kubectl describe svc -n postgresql postgresql
```

---

## Next Steps

1. ✅ PostgreSQL is accessible from local network
2. ⏳ Implement sealed-secrets for encrypted credentials
3. ⏳ Set up automated backups
4. ⏳ Configure monitoring/alerting for PostgreSQL
