# Day-2 operations checklist for AKS

Use it as a starting point for your own team. Tick what you have; plan the rest.

## Observability
- [ ] Managed Prometheus on, with a dashboard people actually open
- [ ] Alerts go to a person or a channel, not an unread mailbox
- [ ] Every alert says what to do next (a runbook link)
- [ ] Alerts are about user pain (errors, latency, saturation), not every pod restart
- [ ] You know how long metrics and logs are kept, and what they cost

## Resilience
- [ ] At least 3 replicas for anything that must stay up
- [ ] Topology spread across nodes and zones
- [ ] Readiness and liveness probes that mean something
- [ ] A PodDisruptionBudget for each important workload (not so strict that drains hang)
- [ ] A graceful shutdown (preStop sleep, terminationGracePeriodSeconds)
- [ ] A game day at least once a quarter: kill a pod, drain a node, then something bigger

## Upgrades
- [ ] An auto-upgrade channel chosen on purpose
- [ ] Maintenance windows that match your quiet hours
- [ ] A non-production cluster that upgrades first
- [ ] You read the AKS release notes for removed APIs before each minor version
- [ ] A rollback story you have actually rehearsed

## Cost
- [ ] A budget with alerts on the resource group
- [ ] Tags for owner and environment, so cost can be split
- [ ] Requests close to real use (check monthly)
- [ ] Spot for interruptible work only
- [ ] Dev and test clusters are stopped or deleted when not in use
- [ ] Unattached disks and public IPs get cleaned up

## Backup and recovery
- [ ] You know which data is in the cluster and which is outside it
- [ ] Manifests live in Git (Session 2), so the cluster can be rebuilt
- [ ] Persistent volumes are backed up (see backup-notes.md)
- [ ] You have restored a backup, not just taken one
