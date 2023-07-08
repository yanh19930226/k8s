集群搭建地址:https://blog.51cto.com/u_11409186/5743294



(1) rabbitmq端口号说明
4369    # erlang 发现端口
5672    # client 端通信端口
15672   # 管理界面 ui 端口
25672   # server 间内部通信端口
访问 RabbitMQ 管理界面:  http://IP:15672/
连接 RabbitMQ 用client端通信端口:  amqp://guest:guest@localhost:5672/

(2) yml文件中的脚本说明
1) 修改域名解析
if [ -z "$(grep rabbitmq-cluster.rabbitmq-cluster.svc.cluster.local /etc/resolv.conf)" ]; then
  cp -a /etc/resolv.conf /etc/resolv.conf.bak;
  sed "s/^search \([^ ]\+\)/search rabbitmq-cluster.\1 \1/" /etc/resolv.conf > /etc/resolv.conf.new;
  cat /etc/resolv.conf.new > /etc/resolv.conf;
  rm /etc/resolv.conf.new;
fi;

说明:
因为rabbitmq节点加入集群需要使用主机名，添加rabbitmq集群所在svc的域名配置，方便rabbitmq直接使用主机名进行访问，/etc/resolv.conf

2) 将rabbitmq节点加入集群
until rabbitmqctl node_health_check; do sleep 1; done;
if [ -z "$(rabbitmqctl cluster_status | grep rabbitmq-cluster-0)" ]; then
  touch /gotit
  rabbitmqctl stop_app;
  rabbitmqctl reset;
  rabbitmqctl join_cluster rabbit@rabbitmq-cluster-0;
  rabbitmqctl start_app;
else
  touch /notget
fi;

说明:
rabbitmq服务启动并且健康检查通过后，将该rabbitmq节点以rabbitmq-cluster-0主机名为基准加入集群中


1 创建命名空间
kubectl create namespace rabbitmq-cluster

2 应用配置文件
kubectl apply -f rabbitmq-cluster.yml 
service/rabbitmq-cluster-management created
service/rabbitmq-cluster created
statefulset.apps/rabbitmq-cluster created

3 查看 rabbitmq 集群 pod
kubectl get pod -n rabbitmq-cluster

4 查看 rabbitmq 集群 pvc、pv
kubectl get pvc -n rabbitmq-cluster
kubectl get pv

5 查看 rabbitmq 集群 svc
kubectl get svc,ep -n rabbitmq-cluster

6 查看 rabbitmq 集群 nfs 共享存储
 ls -l /nfs/data/rabbitmq/
 ls -l /nfs/data/rabbitmq/*/

# RabbitMQ的三个容器节点的.erlang.cookie内容是一致的
 cat /nfs/data/rabbitmq/*/.erlang.cookie

7 验证RabbitMQ集群
kubectl exec -it pod/rabbitmq-cluster-0 -n rabbitmq-cluster -- bash
rabbitmqctl cluster_status

8 访问 rabbitmq 集群的 web 界面，查看集群的状态
访问 http://<nodeip>:30072，用户名和密码都是 guest

