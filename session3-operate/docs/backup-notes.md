# Backup notes

This session talks about backup but does not ship a one-click script: the setup involves a backup vault,
a storage account, an AKS backup extension and trusted access, and the exact steps change between releases.
Follow the current Microsoft guide instead: search for **"Back up AKS using Azure Backup"** on Microsoft Learn.

What to understand first

- **GitOps is your first backup.** If every manifest is in Git, you can rebuild a cluster. See Session 2.
- **State is the hard part.** Persistent volumes and anything stored in the cluster (for example secrets that
  were created by hand) are what Azure Backup for AKS protects.
- **Data outside the cluster** (databases, storage accounts, Key Vault) needs its own backup. Do not
  assume cluster backup covers it.
- **A backup you never restored is a hope, not a backup.** Practise a restore into a different cluster.
- **Decide the targets:** how much data you can lose (RPO) and how long you can be down (RTO).
