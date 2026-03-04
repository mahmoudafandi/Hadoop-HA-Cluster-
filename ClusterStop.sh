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