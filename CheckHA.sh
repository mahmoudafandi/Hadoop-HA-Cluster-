
#! /bin/bash 
echo "=== HA Status ==="
echo "NN STATUS FOR node01"
echo "     "
/opt/hadoop/bin/hdfs haadmin -getServiceState nn1
echo "     "
echo "NN STATUS FOR node02"
echo "     "
/opt/hadoop/bin/hdfs haadmin -getServiceState nn2
echo "     "
echo "RM STATUS FOR node01"
echo "     "
/opt/hadoop/bin/yarn rmadmin -getServiceState rm1
echo "     "
echo "RM STATUS FOR node02"
echo "     "
/opt/hadoop/bin/yarn rmadmin -getServiceState rm2
