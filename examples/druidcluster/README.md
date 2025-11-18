# Druid Cluster Docker Compose Example

This directory contains a complete Docker Compose setup for running a full Apache Druid cluster locally. This example is perfect for development, testing, and learning about Druid cluster architecture.

## Overview

This Docker Compose configuration sets up a complete Druid cluster with all necessary components:

- **PostgreSQL** - Metadata storage database
- **Apache ZooKeeper** - Coordination service
- **Druid Coordinator** - Manages data availability and segment lifecycle
- **Druid Broker** - Handles queries from external clients
- **Druid Historical** - Stores and serves historical data segments
- **Druid MiddleManager** - Manages ingestion tasks
- **Druid Router** - Routes queries and provides unified API endpoint
  
Note: An optional Druid MCP Server service exists but is commented out in the compose file. See the optional integration note below if you want to enable it.

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 8GB of available RAM
- At least 10GB of free disk space

### Starting the Cluster

1. Navigate to this directory:
   ```bash
   cd examples/druidcluster
   ```

2. Start the cluster:
   ```bash
   docker compose up -d
   ```

3. Open the Druid Console and confirm access:
   - URL: http://localhost:8888
   - Username: admin
   - Password: password

4. Configure Data Philter to connect to this local cluster. Edit  `~/.data-philter/druid.env` and set at least:
```bash
   DRUID_ROUTER_URL=http://localhost:8888
   DRUID_SSL_ENABLED=false
   DRUID_AUTH_USERNAME=admin
   DRUID_AUTH_PASSWORD=password
   ```

5. Start Data Philter (in the repo root) and open the app:
   ```bash
   docker compose up -d
   ```
   - App URL: http://localhost:4000

### Stopping the Cluster

```bash
docker compose down
```

To also remove volumes (delete all data):
```bash
docker compose down -v
```

## Service Details

### Core Services

| Service | Container | Image | Purpose | Dependencies |
|---------|-----------|-------|---------|--------------|
| **PostgreSQL** | `postgres` | `postgres:17` | Metadata storage | None |
| **ZooKeeper** | `zookeeper` | `zookeeper:3.5.10` | Service coordination | None |
| **Coordinator** | `coordinator` | `apache/druid:34.0.0` | Segment management | postgres, zookeeper |
| **Broker** | `broker` | `apache/druid:34.0.0` | Query processing | postgres, zookeeper, coordinator |
| **Historical** | `historical` | `apache/druid:34.0.0` | Data serving | postgres, zookeeper, coordinator |
| **MiddleManager** | `middlemanager` | `apache/druid:34.0.0` | Task execution | postgres, zookeeper, coordinator |
| **Router** | `router` | `apache/druid:34.0.0` | API gateway | postgres, zookeeper, coordinator |

### Port Mappings

| Service | Internal Port | External Port | Purpose |
|---------|---------------|---------------|---------|
| Router | 8888 | 8888 | Druid Console & API |

### Volume Mappings

| Volume | Purpose | Mounted Services |
|--------|---------|------------------|
| `metadata_data` | PostgreSQL data persistence | postgres |
| `druid_shared` | Shared segment storage | coordinator, historical, middlemanager |
| `coordinator_var` | Coordinator logs and temp files | coordinator |
| `broker_var` | Broker logs and temp files | broker |
| `historical_var` | Historical logs and temp files | historical |
| `middle_var` | MiddleManager logs and temp files | middlemanager |
| `router_var` | Router logs and temp files | router |

## Configuration

### Environment Variables

The cluster uses configuration from the `environment` file. Key settings include:

#### Database Configuration
```bash
druid_metadata_storage_type=postgresql
druid_metadata_storage_connector_connectURI=jdbc:postgresql://postgres:5432/druid
druid_metadata_storage_connector_user=druid
druid_metadata_storage_connector_password=FoolishPassword
```

#### ZooKeeper Configuration
```bash
druid_zk_service_host=zookeeper
```

#### Storage Configuration
```bash
druid_storage_type=local
druid_storage_storageDirectory=/opt/shared/segments
druid_indexer_logs_directory=/opt/shared/indexing-logs
```

#### Performance Tuning
```bash
DRUID_SINGLE_NODE_CONF=micro-quickstart
druid_processing_numThreads=2
druid_processing_numMergeBuffers=2
```

#### Security

This example enables Druid Basic Security with initial credentials for convenience:

```bash
# Initial admin user and internal client passwords
druid_auth_authenticator_MyBasicMetadataAuthenticator_initialAdminPassword=password
druid_escalator_internalClientPassword=internal
```

Default login for the Druid Console:

- Username: admin
- Password: password

### Customizing Configuration

To modify the cluster configuration:

1. Edit the `environment` file
2. Restart the cluster:
   ```bash
   docker compose down
   docker compose up -d
   ```

## Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check service logs
docker compose logs [service-name]

# Check all services status
docker compose ps
```

#### Out of Memory Errors
- Increase Docker memory allocation to at least 8GB
- Modify memory settings in the `environment` file

#### Port Conflicts
- Ensure port 8888 (Druid Router) is not in use by other applications
- Modify port mappings in `docker-compose.yaml` if needed

#### Data Persistence Issues
```bash
# Remove all volumes and start fresh
docker compose down -v
docker compose up -d
```

### Health Checks

Check if all services are running:
```bash
# View running containers
docker compose ps

# Check specific service logs
docker compose logs coordinator
docker compose logs broker

# Follow logs in real-time
docker compose logs -f
```

### Performance Monitoring

Monitor resource usage:
```bash
# View resource usage
docker stats

# Check Druid metrics via API
curl http://localhost:8888/status/health

# (Optional) If you added extra services, check their health here
```

## Sample Data Ingestion

Once the cluster is running, you can test it with sample data:

### Using the Druid Console
1. Go to http://localhost:8888
2. Click "Load data" → "Batch - classic"
3. Use the sample data provided in Druid tutorials

## Cleanup

### Remove Everything
```bash
# Stop and remove containers, networks, and volumes
docker compose down -v --rmi all
```
---

## About iunera

This Docker Compose example is developed and maintained by **[iunera](https://www.iunera.com)**, a leading provider of advanced AI and data analytics solutions.

For more information about our enterprise solutions and professional services, visit [www.iunera.com](https://www.iunera.com).

---

*© 2025 [iunera](https://www.iunera.com). Licensed under the Apache License 2.0.*
