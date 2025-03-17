# SummitEthic Backup and Restore Procedures

## Overview

This document outlines the backup and restore procedures for SummitEthic infrastructure. It covers backup strategies, verification, and recovery procedures to ensure data integrity and availability.

## Backup Strategy

SummitEthic implements a comprehensive backup strategy following the 3-2-1 principle:

- 3 copies of data
- 2 different storage media
- 1 copy off-site

### Backup Types

| Type                 | Frequency | Retention | Description                            |
| -------------------- | --------- | --------- | -------------------------------------- |
| System Configuration | Daily     | 30 days   | OS and application configuration files |
| Database             | Hourly    | 7 days    | Database dumps and transaction logs    |
| Application Data     | Daily     | 90 days   | User uploads and application state     |
| Full System          | Weekly    | 90 days   | Full server images or snapshots        |
| Archival             | Monthly   | 1 year    | Long-term storage of critical data     |

### Backup Locations

1. **Primary Storage**: Local backup server with RAID protection
2. **Secondary Storage**: Cloud object storage (encrypted)
3. **Offline Storage**: Cold storage for monthly archival backups

## Backup Implementation

The backup system is implemented using Ansible roles and scheduled via cron jobs.

### System Configuration Backup

System configuration backups include:

- `/etc` directory
- Service configuration files
- SSL certificates
- User accounts and permissions
- Firewall rules
- Cron jobs

These backups are performed using the `backup.yml` playbook:

```bash
make backup ENV=environment
```

### Database Backup

Database backups include:

- Full database dumps
- Transaction logs for point-in-time recovery
- Schema-only backups

For manual database backup:

```bash
ansible-playbook -i ansible/inventories/ENV/inventory.yml ansible/playbooks/database.yml --tags backup
```

### Application Data Backup

Application data includes user uploads, application state, and other persistent data. These are backed up using:

```bash
ansible-playbook -i ansible/inventories/ENV/inventory.yml ansible/playbooks/backup.yml --tags app-data
```

## Backup Verification

All backups must be verified to ensure they are usable for recovery:

### Automated Verification

1. **Integrity Checks**: Checksums are verified for all backup files
2. **Corruption Detection**: Database dumps are validated for corruption
3. **Size Verification**: Backup sizes are compared against expected ranges

### Manual Verification

Quarterly, a full recovery test should be performed to verify backup usability:

1. Select a random backup set
2. Restore to an isolated recovery environment
3. Verify application functionality
4. Document findings and improvements

## Restoration Procedures

In the event data restoration is needed, follow these procedures:

### System Configuration Restoration

To restore system configuration:

```bash
ansible-playbook -i ansible/inventories/ENV/inventory.yml ansible/playbooks/restore_system.yml -e "backup_date=YYYY-MM-DD"
```

### Database Restoration

To restore a database:

```bash
ansible-playbook -i ansible/inventories/ENV/inventory.yml ansible/playbooks/restore_database.yml -e "backup_date=YYYY-MM-DD backup_time=HH-MM"
```

### Full System Restoration

In case of complete system failure:

1. Provision new server instances
2. Restore system configuration
3. Restore databases
4. Restore application data
5. Verify services and functionality

```bash
ansible-playbook -i ansible/inventories/ENV/inventory.yml ansible/playbooks/disaster_recovery.yml -e "backup_date=YYYY-MM-DD"
```

## Ethical Considerations

When performing backup and restoration activities, consider these ethical guidelines:

1. **Data Privacy**: Backups contain sensitive information and must be encrypted
2. **Retention Limits**: Data should not be retained longer than necessary
3. **Resource Usage**: Backup jobs should be scheduled during low-usage periods
4. **Access Control**: Limit access to backup data to authorized personnel
5. **Environmental Impact**: Optimize storage to reduce resource consumption

## Special Scenarios

### Point-in-Time Recovery

For database point-in-time recovery:

1. Restore the last full backup
2. Apply transaction logs up to the desired point in time

```bash
ansible-playbook -i ansible/inventories/ENV/inventory.yml ansible/playbooks/restore_database.yml -e "backup_date=YYYY-MM-DD recover_until='YYYY-MM-DD HH:MM:SS'"
```

### Partial Restoration

To restore specific components:

```bash
ansible-playbook -i ansible/inventories/ENV/inventory.yml ansible/playbooks/restore_component.yml -e "component=COMPONENT_NAME backup_date=YYYY-MM-DD"
```

### Emergency Access

In case of emergency restoration needs when normal channels are unavailable:

1. Contact the Disaster Recovery team lead
2. Use emergency access credentials stored in the secure vault
3. Follow emergency restoration procedures in the disaster recovery manual

## Troubleshooting

Common issues during backup and restore operations:

| Issue              | Possible Cause          | Resolution                                                 |
| ------------------ | ----------------------- | ---------------------------------------------------------- |
| Backup Failure     | Insufficient disk space | Clear old backups, increase storage allocation             |
| Corrupt Backup     | Storage media failure   | Restore from secondary backup location                     |
| Missing Files      | Incomplete backup       | Check backup logs for errors, restore from previous backup |
| Permissions Issues | Incorrect ownership     | Check backup and target permissions, adjust as needed      |
| Performance Impact | Resource contention     | Adjust backup schedule, optimize resource allocation       |

## Monitoring and Alerting

The backup system is monitored to ensure proper operation:

1. Success/failure notifications are sent via email
2. Backup metrics are recorded in Prometheus
3. Grafana dashboards provide visibility into backup health
4. Automated alerting for missed or failed backups

## Responsibilities

| Role                    | Responsibilities                         |
| ----------------------- | ---------------------------------------- |
| DevOps Team             | Implement and maintain backup system     |
| System Administrators   | Monitor backup success/failure           |
| Database Administrators | Verify database backup integrity         |
| Security Team           | Audit backup access and encryption       |
| Disaster Recovery Team  | Test and validate restoration procedures |

## References

- [SummitEthic Disaster Recovery Plan](./disaster_recovery.md)
- [Data Retention Policy](../governance/data_retention.md)
- [Backup Scripts Repository](https://github.com/summitethic/backup-scripts)
