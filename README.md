# Hadoop-HA-Cluster-
A Documentation of the Hadoop HA cluster for ITI's Hadoop course 

Table of contents 

| Segment 1  | Hadoop Cluster Architecture  |
| ---------- | ------------------------------------- |
| Segement 2 | Configuration Files     |
| Segement 3 | Complementary Scripts       |


----

# Hadoop Cluster Architecture 


## Node Layout

| Node   | Role                           | Services                                      |
| ------ | ------------------------------ | --------------------------------------------- |
| node01 | Master –  Active NameNode / RM | NameNode, ZKFC                                |
| node02 | Master – Standby NameNode      | NameNode, ZKFC, ResourceManager               |
| node03 | Worker                         | DataNode, NodeManager, ZooKeeper, JournalNode |
| node04 | Worker                         | DataNode, NodeManager, ZooKeeper, JournalNode |
| node05 | Worker                         | DataNode, NodeManager, ZooKeeper, JournalNode |

---

## HDFS High AvailabilityHA Architecure.png

HDFS is configured in high availability mode with two NameNodes — one active and one standby. Three components work together to make this possible.

### NameNodes

The active NameNode (node02) handles all client requests and filesystem metadata operations. The standby NameNode (node01) mirrors the active node's state and is ready to take over immediately if the active node fails.

### JournalNodes




JournalNodes run on node03, node04, and node05. When the active NameNode makes any filesystem change, it writes an edit log entry to a quorum of JournalNodes. The standby NameNode continuously reads these edits to stay in sync, ensuring it is fully up to date at the moment of failover. Three JournalNodes are used so that one can fail without interrupting the edit log.

### ZooKeeper Failover Controllers (ZKFC)

A ZKFC daemon runs alongside each NameNode on node01 and node02. It monitors the health of its local NameNode and coordinates with ZooKeeper to perform automatic failover. If the active NameNode becomes unresponsive, the ZKFC detects this and triggers a controlled promotion of the standby to active.

---

## ZooKeeper

A three-node ZooKeeper quorum runs on node03, node04, and node05. ZooKeeper serves two purposes in this cluster:

- **HDFS failover coordination** — works with ZKFC to elect the active NameNode.
- **YARN RM state storage** — the ResourceManager persists application state to ZooKeeper, enabling YARN failover without a separate journal.

An odd number of ZooKeeper nodes (3) is required to ensure a majority quorum can always be reached. With three nodes, one can fail and the cluster continues operating normally.

---

## YARN

YARN manages compute resources across the cluster. The ResourceManager runs on node02 and is started via `start-yarn.sh`, which also SSHs into each node in the workers file to start a NodeManager. node01 and node02 are excluded from the workers file so they do not run NodeManagers.

### YARN Failover

Unlike HDFS, YARN does not require JournalNodes — it stores application state directly in ZooKeeper. If YARN HA is configured, a standby ResourceManager runs on node01. If the active RM fails, the standby reads state from ZooKeeper and promotes itself automatically.

---

## Startup Order

The cluster must be started in a specific sequence to satisfy service dependencies.

|Step|Service|Nodes|Reason|
|---|---|---|---|
|1|ZooKeeper|node03, 04, 05|All other HA components depend on ZooKeeper being available first.|
|2|JournalNodes|node03, 04, 05|Must be running before NameNodes start writing edit logs.|
|3|NameNodes|node01, node02|Both start; one becomes active, the other standby.|
|4|ZKFC|node01, node02|Monitors NameNodes and manages failover via ZooKeeper.|
|5|DataNodes|node03, 04, 05|Register with the active NameNode after it is online.|
|6|YARN|node02 + workers|Starts RM locally and NodeManagers on worker nodes via SSH.|


<img width="989" height="680" alt="HA Architecure" src="https://github.com/user-attachments/assets/ef3b56c7-a479-48d4-941d-2cbcc0887dde" />


----

# Configuration Files


## core-site.xml

This is the top-level Hadoop config, shared across all components.

|Property|Value|Purpose|
|---|---|---|
|`fs.defaultFS`|`hdfs://mycluster`|Points the entire cluster at the HA nameservice rather than a single NameNode hostname. Clients resolve the active NameNode automatically.|
|`ha.zookeeper.quorum`|`node03:2181, node04:2181, node05:2181`|Tells HDFS and YARN where the ZooKeeper quorum is running. Used by ZKFC for NameNode failover and by YARN for RM state storage.|

---

## hdfs-site.xml

Controls HDFS behaviour, HA topology, and storage paths.

### Replication

|Property|Value|Note|
|---|---|---|
|`dfs.replication`|`1`|Each block is stored on one DataNode only. The default is 3. This is acceptable for a development or test environment but means there is no redundancy at the data level — if a DataNode is lost, its blocks are gone.|

### Nameservice & NameNodes

|Property|Value|Purpose|
|---|---|---|
|`dfs.nameservices`|`mycluster`|Logical name for the HA cluster, referenced throughout the config and by clients.|
|`dfs.ha.namenodes.mycluster`|`nn1, nn2`|Declares two NameNodes within the nameservice.|
|`dfs.namenode.rpc-address.mycluster.nn1`|`node01:9000`|RPC address for nn1 — used by DataNodes and clients to communicate with the NameNode.|
|`dfs.namenode.rpc-address.mycluster.nn2`|`node02:9000`|RPC address for nn2.|
|`dfs.namenode.http-address.mycluster.nn1`|`node01:9870`|Web UI for nn1.|
|`dfs.namenode.http-address.mycluster.nn2`|`node02:9870`|Web UI for nn2.|

### JournalNodes

|Property|Value|Purpose|
|---|---|---|
|`dfs.namenode.shared.edits.dir`|`qjournal://node03:8485;node04:8485;node05:8485/mycluster`|Defines the JournalNode quorum that the active NameNode writes edit logs to, and the standby reads from.|

### Storage Paths

| Property                | Value                   | Purpose                                                               |
| ----------------------- | ----------------------- | --------------------------------------------------------------------- |
| `dfs.namenode.name.dir` | `/hadoop_data/namenode` | Local disk path on each NameNode where filesystem metadata is stored. |
| `dfs.datanode.data.dir` | `/hadoop_data/datanode` | Local disk path on each DataNode where block data is stored.          |

### Automatic Failover

|Property|Value|Purpose|
|---|---|---|
|`dfs.ha.automatic-failover.enabled`|`true`|Enables ZKFC-driven automatic failover between NameNodes.|
|`dfs.client.failover.proxy.provider.mycluster`|`ConfiguredFailoverProxyProvider`|Tells HDFS clients how to locate the active NameNode when one fails over.|
|`dfs.ha.fencing.methods`|`shell(/bin/true)`|Fencing is the mechanism used to ensure the old active NameNode cannot continue writing after failover. This is set to a no-op (`/bin/true`), meaning no actual fencing is performed. Acceptable in a controlled environment but should be reviewed for production use.|

---

## yarn-site.xml

Controls YARN resource management and HA configuration.

### Resource Manager HA

|Property|Value|Purpose|
|---|---|---|
|`yarn.resourcemanager.ha.enabled`|`true`|Enables RM high availability.|
|`yarn.resourcemanager.cluster-id`|`yarn-cluster`|Logical identifier for the YARN cluster, used by ZooKeeper to namespace RM state.|
|`yarn.resourcemanager.ha.rm-ids`|`rm1, rm2`|Declares two ResourceManagers.|
|`yarn.resourcemanager.hostname.rm1`|`node01`|rm1 runs on node01.|
|`yarn.resourcemanager.hostname.rm2`|`node02`|rm2 runs on node02.|
|`yarn.resourcemanager.webapp.address.rm1`|`node01:8480`|Web UI for rm1. Note: non-standard port — the default is 8088.|
|`yarn.resourcemanager.webapp.address.rm2`|`node02:8480`|Web UI for rm2.|
|`yarn.resourcemanager.ha.automatic-failover.enabled`|`true`|Enables automatic RM failover via ZooKeeper.|
|`yarn.resourcemanager.zk-address`|`node03:2181, node04:2181, node05:2181`|ZooKeeper quorum used for RM state storage and leader election.|
|`yarn.resourcemanager.store.class`|`ZKRMStateStore`|Instructs the RM to persist application state in ZooKeeper, allowing the standby RM to recover running jobs on failover.|

### NodeManager

|Property|Value|Purpose|
|---|---|---|
|`yarn.nodemanager.aux-services`|`mapreduce_shuffle`|Enables the shuffle service required for MapReduce jobs to transfer intermediate data between map and reduce tasks.|

---

## Summary of Ports

|Service|Node(s)|Port|
|---|---|---|
|NameNode RPC|node01, node02|9000|
|NameNode Web UI|node01, node02|9870|
|JournalNode|node03, 04, 05|8485|
|ZooKeeper|node03, 04, 05|2181|
|ResourceManager Web UI|node01, node02|8480|

---

# Complementary Scripts :MHadoop:


## Cluster Start & Stop Procedures

All startup and shutdown operations are performed from **node02** using scripts located in `/shared/`.

---

### Starting the Cluster

**Script:** `/shared/ClusterStart.sh`  
Run as `root` from node02.

The startup sequence is strict — each layer depends on the one before it, so services must come up in order.

### 1. ZooKeeper

ZooKeeper is started first across node03, node04, and node05. Everything else — HDFS failover, YARN state storage, and leader election — depends on ZooKeeper being available before any other service attempts to connect.

### 2. JournalNodes

Started on node03, node04, and node05 before the NameNodes. The active NameNode will begin writing edit logs to the JournalNode quorum immediately on startup, so they must be ready first.

### 3. NameNodes

Both NameNodes are started — node01 via SSH, node02 locally. ZooKeeper and ZKFC will negotiate which becomes active and which becomes standby. At this point neither should be assumed active until ZKFC is running.

### 4. ZKFC

Started on both nodes immediately after the NameNodes. ZKFC registers each NameNode with ZooKeeper and performs the election. After this step one NameNode will be **active** and the other **standby**.

### 5. DataNodes

Started on node03, node04, and node05 after the active NameNode is elected. DataNodes register with the active NameNode on startup.

### 6. YARN

`start-yarn.sh` is run locally on node02. This starts rm2 locally and SSHs into the workers file nodes to start NodeManagers. rm1 on node01 is brought up as part of this as YARN HA is configured — ZooKeeper then elects which RM is active.

### 7. Status Check

After startup the script automatically runs a health check by calling `jps` on every node and querying HA state directly:

- `hdfs haadmin -getServiceState nn1/nn2` — reports whether each NameNode is **active** or **standby**.
- `yarn rmadmin -getServiceState rm1/rm2` — reports whether each ResourceManager is **active** or **standby**.

This confirms the cluster has started cleanly and HA election has completed successfully.

```bash
#!/bin/bash

echo "=== Starting ZooKeeper ==="
ssh root@node03 "/opt/zookeeper/bin/zkServer.sh start"
ssh root@node04 "/opt/zookeeper/bin/zkServer.sh start"
ssh root@node05 "/opt/zookeeper/bin/zkServer.sh start"
sleep 5
echo "=== Starting JournalNodes ==="
ssh root@node03 "/opt/hadoop/bin/hdfs --daemon start journalnode"
ssh root@node04 "/opt/hadoop/bin/hdfs --daemon start journalnode"
ssh root@node05 "/opt/hadoop/bin/hdfs --daemon start journalnode"
sleep 5
echo "=== Starting NameNodes ==="
ssh root@node01 "/opt/hadoop/bin/hdfs --daemon start namenode"
/opt/hadoop/bin/hdfs --daemon start namenode 
sleep 5
echo "=== Starting ZKFC ==="
ssh root@node01 "/opt/hadoop/bin/hdfs --daemon start zkfc"
/opt/hadoop/bin/hdfs --daemon start zkfc
sleep 3
echo "=== Starting DataNodes ==="
ssh root@node03 "/opt/hadoop/bin/hdfs --daemon start datanode"
ssh root@node04 "/opt/hadoop/bin/hdfs --daemon start datanode"
ssh root@node05 "/opt/hadoop/bin/hdfs --daemon start datanode"
sleep 3
echo "=== Starting YARN ==="
/opt/hadoop/sbin/start-yarn.sh
sleep 3
echo "=== Cluster Status ==="
echo "--- node01 ---"
ssh root@node01 "jps"
echo "--- node02 ---"
jps
echo "--- node03 ---"
ssh root@node03 "jps"
echo "--- node04 ---"
ssh root@node04 "jps"
echo "--- node05 ---"
ssh root@node05 "jps"
echo "=== HA Status ==="
echo "NN STATUS FOR node01"
echo "     "
/opt/hadoop/bin/hdfs haadmin -getServiceState nn1
echo "NN STATUS FOR node02"
echo "     "
/opt/hadoop/bin/hdfs haadmin -getServiceState nn2
echo "RM STATUS FOR node01"
echo "     "
/opt/hadoop/bin/yarn rmadmin -getServiceState rm1
echo "RM STATUS FOR node02"
echo "     "
/opt/hadoop/bin/yarn rmadmin -getServiceState rm2
```

---

### Stopping the Cluster

**Script:** `/shared/ClusterStop.sh`  
Run as `root` from node02.

Shutdown is the reverse of startup — higher-level services are stopped first before the coordination layer beneath them is brought down.

#### 1. YARN

`stop-yarn.sh` stops the ResourceManagers and all NodeManagers across the cluster.

#### 2. HDFS

`stop-dfs.sh` stops NameNodes, DataNodes, JournalNodes, and ZKFC across all nodes. This is handled by Hadoop's own wrapper script rather than explicit SSH calls.

#### 3. ZooKeeper

Stopped last on node03, node04, and node05. ZooKeeper is shut down after HDFS and YARN are fully stopped to ensure no running services lose their coordination layer mid-shutdown.


```bash 

#!/bin/bash

echo "=== Stopping YARN ==="
/opt/hadoop/sbin/stop-yarn.sh
sleep 3

echo "=== Stopping HDFS ==="
/opt/hadoop/sbin/stop-dfs.sh
sleep 3

echo "=== Stopping ZooKeeper ==="
ssh root@node03 "/opt/zookeeper/bin/zkServer.sh stop"
ssh root@node04 "/opt/zookeeper/bin/zkServer.sh stop"
ssh root@node05 "/opt/zookeeper/bin/zkServer.sh stop"

echo "=== Cluster stopped cleanly ==="

```


---

## Key Paths

| Item                | Path                      |
| ------------------- | ------------------------- |
| Start script        | `/shared/ClusterStart.sh` |
| Stop script         | `/shared/ClusterStop.sh`  |
| Hadoop binaries     | `/opt/hadoop/bin/`        |
| Hadoop sbin scripts | `/opt/hadoop/sbin/`       |
| ZooKeeper binaries  | `/opt/zookeeper/bin/`     |
