#!/bin/bash

# Подключитесь к серверу конфигурации и сделайте инициализацию:
docker compose exec -T configSrv mongosh --port 27018 --quiet <<EOF

rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27018" }
    ]
  }
)
EOF


# Инициализируйте репликацию для shard1:
docker compose exec -T shard1_node1 mongosh --port 27019 --quiet <<EOF

rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1_node1:27019" },
        { _id : 1, host : "shard1_node2:27020" },
        { _id : 2, host : "shard1_node3:27021" }
      ]
    }
)
EOF


# Инициализируйте репликацию для shard2:
docker compose exec -T shard2_node1 mongosh --port 27022 --quiet <<EOF

rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2_node1:27022" },
        { _id : 1, host : "shard2_node2:27023" },
        { _id : 2, host : "shard2_node3:27024" }
      ]
    }
  )
EOF

#Инцициализируйте роутер и наполните его тестовыми данными:
docker compose exec -T mongos_router mongosh --port 27017 --quiet <<EOF

sh.addShard( "shard1/shard1_node1:27019");
sh.addShard( "shard2/shard2_node1:27022");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

use somedb

for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})

db.helloDoc.countDocuments()
EOF


# Проверка распределения документов по шардам и репликам
docker compose exec -T shard1_node1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard1_node2 mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard1_node3 mongosh --port 27021 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2_node1 mongosh --port 27022 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2_node2 mongosh --port 27023 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2_node3 mongosh --port 27024 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
