---
title: "Why Redis is not designed for multi cloud environment"
date: 2023-08-14T17:29:21+02:00
draft: false
tags: ["db", "cloud"]

resources:
- name: "logo"
  src: "logo.png"

featuredImage: "logo"

---
# Introduction
Deploying a Redis database on multiple cloud providers may seem like a logical choice to ensure high availability and survive potential disasters. 
However, before diving into this approach, it's important to carefully consider the node topologies and weigh the benefits against the complexities involved. 
In this blog post, we will delve into the reasons why deploying Redis on multiple clouds may not be worth the effort, focusing on node topologies that can maximize data availability.

{{< admonition tip >}}
If you are already familiar with the advantages and disadvantages of a multi-cloud environment, as well as the different versions of Redis, feel free to skip the paragraphs discussing the multi-cloud environment and types of Redis. 
You can proceed directly to the section _[Topology](#topology)_.
{{< /admonition >}}

# Multi cloud environment
In the following paragraphs, we will discuss the advantages and disadvantages of a multi-cloud environment, exploring the benefits it brings as well as the challenges it presents.

## Surviving region disasters
One of the primary motivations for deploying Redis on multiple clouds is to mitigate the impact of a disaster occurring in a specific cluster or region. 
By spreading the database across different cloud providers, the intention is to ensure that the data remains available even if one provider experiences an outage or failure.

## High availability for data
Ensuring high availability for data, especially in the case of databases, is crucial for businesses that rely on real-time data access. 
By deploying Redis on two or more cloud providers, the aim is to maintain data availability even in the event of infrastructure issues or disruptions.

## The complexity of multi-cloud deployments
While the idea of multi-cloud deployments may sound promising, the practical implementation can be complex and challenging. 
Coordinating and synchronizing data across multiple clouds requires careful planning, robust infrastructure, and thorough monitoring. 
Ensuring data consistency and minimizing latency can become significant hurdles.

## Data synchronization and latency
When deploying Redis on multiple clouds, data synchronization becomes a critical concern. 
Ensuring that data is replicated and consistent across different clusters in real-time is a non-trivial task. 
Additionally, inter-cloud communication can introduce additional latency, affecting the overall performance and responsiveness of the system.

## Cost and operational overhead
Deploying Redis on multiple cloud providers incurs additional costs and operational overhead. 
Each cloud provider has its own pricing structure, and managing and monitoring resources across multiple platforms can be complex and time-consuming. 
It's essential to consider whether the benefits of redundancy outweigh the increased expenses and management complexities.

# Types of Redis
In the realm of Redis, there exist two distinct versions: the open-source version and the enterprise edition. 

For the purpose of this blog post, **our attention will be directed towards the open-source variant**. 
This version presents users with two different modes: Sentinel and Cluster.

## Redis Sentinel
{{< style "justify-content: center; display: flex;" >}}
![image](./redis-sentinel.drawio.png)
{{< /style >}}

### Overview 
Redis Sentinel is a critical component of Redis, offering high availability and automatic failover for Redis instances. 
It actively monitors the Redis infrastructure, ensuring the well-being of both Redis masters and slaves. 
Sentinel provides automatic notifications to administrators, keeping them informed about any changes in the Redis infrastructure. 
It operates as a separate process or component that seamlessly runs alongside Redis instances. 
In this mode, Redis functions in a master-slave configuration, enabling robust and reliable data management.

### Pros
- automatic failure detection and recovery
- high availability
- works with most clients and plugins

### Cons
- limited scalability
- setup is complex due to additional sentinel processes

## Redis Cluster
{{< style "justify-content: center; display: flex;" >}}
![image](./redis-cluster.drawio.png)
{{< /style >}}

### Overview
Redis Cluster enables horizontal scaling of Redis by distributing data across multiple nodes using automatic sharding. 
It ensures high availability through automatic failover. 
Sharding in Redis Cluster partitions data into hash slots, assigning each slot to a node. 
Nodes are responsible for specific slots, and data is stored accordingly. 
When a client requests data, Redis uses consistent hashing to determine the node holding the data based on the key's hash value.

### Pros
- horizontal scalability
- high availability with automatic failover
- automatic resharding

### Cons
- configuration complexity
- limited support for clients and plugins
- comparing to Redis Sentinel, it has far fewer options for node selection during failover

# Topology
Before delving into specific Redis topologies, it's important to grasp the concepts of split brain and quorum consensus.

## Split brain
Let's imagine that we want to deploy Redis cluster using two or three cloud providers to ensure that Redis will be working during cloud outage.
When we are using multiple clouds we need to be worried about split brain between clouds. 
Split brain is a situation when one cloud can lose connection to another cloud and both clouds lives independent at the same time.

{{< style "justify-content: center; display: flex;" >}}
![image](./redis-splitbrain.drawio.png)
{{< /style >}}

## Quorum Consensus
In a Redis distributed system, *quorum consensus* means the minimum number of nodes that must agree on a decision, like failover, to ensure data consistency and system reliability.

| Number of nodes | Quorum | Allowed number of failing nodes |
|:---------------:|:------:|:-------------------------------:|
|        1        |   1    |                0                |
|        2        |   2    |                0                |
|        3        |   2    |                1                |
|        4        |   3    |                1                |
|        5        |   3    |                2                |
|        6        |   4    |                2                |
|        7        |   4    |                3                |
|        8        |   5    |                3                |
|        9        |   5    |                4                |

## Redis Sentinel
Redis Sentinel, by and large, presents a rather straightforward approach. 
It employs a single master for managing all operations, and in case of a failover, a new master is elected. 
However, in a multi-cloud setup, the major hurdle lies in the substantial network overhead costs. 
The need to pay for data transfers across cloud platforms becomes a notable concern. 
Notably, all data is routed through the master before being disseminated to the various replicas, further contributing to this network expense.

### Configuration 1
- AWS: 3 nodes
- GCP: 2 nodes

{{< style "justify-content: center; display: flex;" >}}
![image](./redis-sentinel-config-1.drawio.png)
{{< /style >}}

#### Problems
- during AWS outage, Redis on GCP becomes unhealthy
- during network glitch, Redis on GCP becomes unhealthy
- cost of network overhead

#### Conclusion
Redis becomes unhealthy when cloud with more nodes has an outage.

Resilient to cloud outage: ❌

### Configuration 2
- AWS: 3 nodes
- GCP: 3 nodes

{{< style "justify-content: center; display: flex;" >}}
![image](./redis-sentinel-config-2.drawio.png)
{{< /style >}}

#### Problems
- during cloud outage Redis on both clouds becomes unhealthy
- during network glitch, Redis on both clouds becomes unhealthy
- cost of network overhead

#### Conclusion
Redis becomes unhealthy when one of the clouds has an outage or there is network issue between clouds.

Resilient to cloud outage: ❌

### Configuration 3
- AWS: 2 nodes
- GCP: 2 nodes
- Azure: 2 nodes

{{< style "justify-content: center; display: flex;" >}}
![image](./redis-sentinel-config-3.drawio.png)
{{< /style >}}

#### Problems
- problematic parallel rolling update
- cost of network overhead

#### Conclusion
Simultaneously implementing a rolling update across all clouds can lead to quorum loss. 
The restart of a single instance on each cloud can disrupt quorum, rendering Redis inaccessible. 
Moreover, utilizing a three-cloud setup proves costly due to network expenses spanning all three clouds.

Resilient to cloud outage: ✅

### Configuration 4
- AWS: 3 nodes
- GCP: 3 nodes
- Azure: 3 nodes

{{< style "justify-content: center; display: flex;" >}}
![image](./redis-sentinel-config-4.drawio.png)
{{< /style >}}

#### Problems
- network overhead
- a large amount of nodes

#### Conclusion
In this configuration, Redis can endure the downtime of a single cloud provider or a split brain situation with one of the clouds. 
However, the primary challenge lies in the substantial cost of this setup, as network expenses for all three clouds are incurred.

Resilient to cloud outage: ✅

## Redis cluster
The Redis cluster lacks options for configuring node preferences in the event of failover. 
There is no mechanism to prioritize or designate node election during failover situations. 
Consequently, specifying configurations to ensure the cluster's survival during a cloud outage becomes significantly more challenging. 

The positive aspect is that due to sharding, the requirement for numerous replicas is minimized, leading to improved data transfer efficiency across clouds. 
However, on the flip side, the absence of a mechanism to prioritize the future master during failover presents a significant predicament. 
This issue will be further elucidated in the subsequent configurations.

Redis Cluster diverges slightly from Redis Sentinel in its failover mechanism. 
In the case of failover, it's noteworthy that **only the master nodes hold the privilege to participate in the voting process to elect a new master**.

### Configuration 1
- AWS: 2 masters (A, B), 1 replica (C)
- GCP: 1 master (C), 2 replicas (A, B)
- 3 shards: A, B, C

{{< style "justify-content: center; display: flex;" >}}
![image](./redis-cluster-config-1.drawio.png)
{{< /style >}}

#### Problems
- during AWS outage, Redis on GCP becomes unhealthy due to not enough masters to vote
- during network glitch, Redis on GCP becomes unhealthy due to not enough masters to vote
- there's no guarantee against all masters being located on a single cloud
- cost of network overhead

#### Conclusion
Redis becomes unhealthy when one of the clouds has an outage or there is network issue between clouds.

Deploying Redis Cluster across just two clouds isn't adequate to ensure resilience against cloud outages. 
While increasing the count of master nodes might be an option, the majority of these masters would still likely reside within a single cloud.

The challenge arises from our inability to designate the locations of master nodes, leaving us unaware of which cloud holds the majority of masters. 
Consequently, it becomes uncertain which cloud will remain functional in the event of an outage in the second cloud.

Resilient to cloud outage: ❌

### Configuration 2
- AWS: 2 masters (A, B), 2 replicas (C, D)
- GCP: 2 masters (C, D), 2 replicas (A, E)
- Azure: 1 master (E), 1 replica (B)
- 5 shards: A, B, C, D, E

{{< style "justify-content: center; display: flex;" >}}
![image](./redis-cluster-config-2.drawio.png)
{{< /style >}}

#### Problems
- there's no guarantee against majority of masters being located on a single cloud
- cost of network overhead 
- a large amount of nodes

#### Conclusion

The presence of the majority of masters on a single cloud lacks any assurance, leading to a scenario where if that particular cloud experiences an outage, the complete Redis cluster becomes non-operational.
The potential to withstand a cloud outage exists, but this relies heavily on the balanced allocation of masters across all clouds.

Surviving a cloud outage necessitates a proportional distribution of master nodes across clouds. However, the task is complicated by the lack of certainty about the master nodes' locations, making this approach an incomplete solution for cloud-related issues.

Even in scenarios where a single cloud houses a majority of master nodes, addressing split brain situations remains an unresolved challenge.

While using three clouds seems like an option to improve redundancy, the cost is substantial due to network overhead.

Resilient to cloud outage: ❌

# Summary

Managing databases in a multi-cloud setup comes with a familiar hurdle: handling the costs tied to networking and the complexities of data replication across various nodes spanning diverse clouds. 
This overhead, including both network expenses and data synchronization complexity, often presents a significant challenge in maintaining an efficient and budget-friendly setup.

Redis Sentinel, a potential solution for multi-cloud setups, offers the prospect of reliable database operations. 
However, it's essential to exercise caution while deploying it.
The number of nodes and the network overhead must be thoughtfully considered to prevent unexpected costs and maintain optimal performance.

However, Redis Cluster isn't as suitable for multi-cloud scenarios due to limitations in placing master nodes across clouds. 
This lack of flexibility hampers its effectiveness. 
Informed decisions between Redis Sentinel and Redis Cluster are vital for architecting a successful multi-cloud database strategy.

# References
- Redis architecture described in detail by [architecutrenotes](https://architecturenotes.co/redis)
- Redis [docs](https://redis.io/docs/)
- Quorum (distributed computing) in details by [wikipedia](https://en.wikipedia.org/wiki/Quorum_(distributed_computing))
- Diagrams by [draw.io](https://draw.io)
- Photo by [J Lee](https://unsplash.com/@babybluecat?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText") on [Unsplash](https://unsplash.com/photos/YTV-GHH9VpQ?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText")
  