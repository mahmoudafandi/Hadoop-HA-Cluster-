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
