# Phoenix LiveView Deployment Guide

## Quick Reference

### Normal Deployment (Preserves Database)
```bash
bash deploy-prod.sh
```
**Use this for:** Code updates, bug fixes, new features
**Database:** Preserved across deployments
**Downtime:** ~30 seconds during pod restart

### Fresh Install (Wipes Database)
```bash
bash deploy-prod.sh --fresh
```
**Use this for:** Complete rebuild, testing, major issues
**Database:** Completely wiped and restored from backup
**Warning:** Any data created after the last backup will be lost

### Quick Updates (No Cache Issues)
```bash
kubectl rollout restart deployment/phoenix-web -n phoenixapp
```
**Use this for:** When you just need to restart pods
**Database:** Unchanged
**Downtime:** ~15 seconds

## How It Works

### Normal Mode (Default)
1. ✅ Backs up current database to `./backups/`
2. ✅ Backs up Redis data
3. ✅ Backs up SSL certificates
4. ✅ **Preserves postgres PVC** (database data stays intact)
5. ✅ Deletes namespace (clears cache)
6. ✅ Rebuilds Docker image
7. ✅ Deploys fresh pods
8. ✅ Reconnects to existing database
9. ✅ Only imports backup if database is empty

### Fresh Install Mode (--fresh flag)
1. ✅ Backs up current database
2. ✅ Backs up Redis data
3. ✅ Backs up SSL certificates
4. ❌ **Does NOT preserve PVC** (database will be wiped)
5. ✅ Deletes namespace including database
6. ✅ Rebuilds Docker image
7. ✅ Deploys fresh pods with new database
8. ✅ Imports most recent backup

## Why This Solves the Cache Problem

**The Issue:** Docker/Kubernetes caches layers aggressively. Without deleting the namespace, old cached code can persist even after rebuilds.

**The Solution:** 
- Namespace deletion clears ALL Kubernetes resources
- Fresh namespace forces Kubernetes to pull the actual latest image
- Database PVC preservation means your data survives the deletion

## Backup Strategy

All backups are stored in `./backups/`:
- Database: `db_backup_YYYYMMDD_HHMMSS.sql` (keeps 10 most recent)
- Redis: `redis_backup_YYYYMMDD_HHMMSS.rdb` (keeps 10 most recent)
- Certificates: `letsencrypt_backup_YYYYMMDD_HHMMSS.yaml` (keeps 10 most recent)

## Troubleshooting

### Database Lost After Deployment
If you used `--fresh` by accident, restore from backup:
```bash
# Check available backups
ls -lht backups/db_backup_*.sql | head -5

# Restore manually
kubectl exec -n phoenixapp deployment/postgres -- sh -c '
PGPASSWORD=postgres psql -U postgres -c "DROP DATABASE phoenixapp_prod;"
PGPASSWORD=postgres psql -U postgres -c "CREATE DATABASE phoenixapp_prod;"
' 
kubectl exec -i -n phoenixapp deployment/postgres -- sh -c 'PGPASSWORD=postgres psql -U postgres -d phoenixapp_prod' < backups/db_backup_YYYYMMDD_HHMMSS.sql
```

### Pods Stuck in Pending
Usually a PVC binding issue:
```bash
kubectl get pvc -n phoenixapp
kubectl describe pvc phoenix-uploads-pvc -n phoenixapp
```
If phoenix-uploads-pvc is Pending, manually create it:
```bash
kubectl delete pvc phoenix-uploads-pvc -n phoenixapp
kubectl apply -f k3s/base/phoenix-uploads-pv.yaml
kubectl apply -f k3s/base/phoenix-uploads-pvc.yaml
```

### Still Using Old Code After Deploy
The namespace deletion should prevent this, but if it happens:
1. Verify image was rebuilt: `docker images | grep phoenixapp`
2. Delete pods manually: `kubectl delete pods -n phoenixapp -l app=phoenix-web`
3. Verify new pods are running: `kubectl get pods -n phoenixapp`

## Best Practices

1. **Always use normal mode** for regular updates
2. **Only use --fresh** when you need a completely clean slate
3. **Backups run automatically** before each deployment
4. **Monitor logs** after deployment: `kubectl logs -n phoenixapp -l app=phoenix-web -f`
5. **Check pod status**: `kubectl get pods -n phoenixapp`

## The Fix Applied

The blog management page was crashing because the template tried to access `@post.featured_image` but only `@editing_post` was assigned. Fixed by changing:
- Line 388: `@post` → `@editing_post`
- Line 391: `@post` → `@editing_post`  
- Line 406: `@post` → `@editing_post`

This fix is now deployed and should work correctly.
