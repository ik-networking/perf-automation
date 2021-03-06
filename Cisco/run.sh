#!/bin/sh
if [ "$#" -ne 5 ]; then
    echo "Usage: run.sh tagName jobName numberOfJobs tcpwindow nodecount"
    exit 1
fi

n=1
while [ $n -le "$3" ]
do

    python preSetup.py $1 $n $2 $4 $5

    echo '*********** Starting the Job ******************'
    if [ $2 = 'dfsio' ]; then 
        nohup time hadoop jar /opt/mapr/hadoop/hadoop-0.20.2/hadoop-0.20.2-dev-test.jar TestDFSIO -write -nrFiles 10 -size 10MB > log &
    elif [ $2 = 'teragen' ]; then
        hadoop fs -rm -r -f -skipTrash /terasort-input
        nohup time hadoop jar /opt/mapr/hadoop/hadoop-0.20.2/hadoop-0.20.2-dev-examples.jar teragen -Ddfs.blocksize=536870912 -Dio.file.buffer.size=131072 -Dmapreduce.map.java.opts=-Xmx1536m -Dmapreduce.map.memory.mb=2048 -Dmapreduce.task.io.sort.mb=768 -Dyarn.app.mapreduce.am.resource.mb=1024 -Dmapred.map.tasks=512 10000000000  /terasort-input > log &
    elif [ $2 = 'terasort' ]; then
        hadoop fs -rm -r -f -skipTrash /terasort-output
        nohup time hadoop jar /opt/mapr/hadoop/hadoop-0.20.2/hadoop-0.20.2-dev-examples.jar terasort -Ddfs.blocksize=536870912 -Dio.file.buffer.size=131072 -Dmapreduce.map.memory.mb=2048 -Dmapreduce.reduce.memory.mb=4096 -Dmapreduce.task.io.sort.factor=100 -Dmapreduce.task.io.sort.mb=1024 -Dmapreduce.map.java.opts=-Xmx1536m -Dmapreduce.reduce.java.opts=-Xmx3072m -Dmapreduce.map.output.compress=true -Dmapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.Lz4Codec -Dyarn.app.mapreduce.am.resource.mb=1024 -Dmapreduce.job.reduces=780 -Dmapreduce.map.disk=0.1 -Dmapreduce.reduce.disk=0.2 /terasort-input /terasort-output > log &
    elif [ $2 = 'spark_terasort' ]; then
        nohup time MASTER=yarn-cluster /opt/mapr/spark/spark-1.5.2/bin/spark-submit --num-executors 600 --class com.github.ehiggs.spark.terasort.TeraSort ~/spark-terasort-master/target/spark-terasort-1.0-SNAPSHOT-jar-with-dependencies.jar maprfs:///terasort-input maprfs:///terasort-output > log &
    else
        echo 'No valid job selected'
    fi

    python collector.py $1 $n $2

    python aggr.py $1 $n

    n=$(( n+1 ))
done

exit 0
