---
title: "Exposing availability zone to Kubernetes pods"
date: 2024-09-02T07:22:12+02:00
draft: false
tags: ["kubernetes", "db", "cloud", "opensearch"]

resources:
- name: "logo"
  src: "logo.jpg"

featuredImage: "logo"

---
# Introduction
In this post, we’ll explore how to expose **Availability Zone (AZ)** information to your Kubernetes pods using the Kubernetes API and an init container. 
As an example, we’ll configure AZ awareness in an OpenSearch database. 
This method, however, can be applied to any application that needs to know the AZ it’s running in. 
By the end of this post, you'll understand how to fetch AZ information and pass it into your pod configuration for better resource allocation and high availability.

# Problem
Kubernetes schedules pods across different nodes, which might be located in multiple Availability Zones (AZs). 
However, it’s not straightforward for a pod to determine the AZ it’s running in, which becomes a problem for applications like OpenSearch that rely on AZ awareness to distribute workloads efficiently.

In OpenSearch, for example, you need to configure [shard allocation awareness](https://opensearch.org/docs/latest/tuning-your-cluster/#advanced-step-6-configure-shard-allocation-awareness-or-forced-awareness) so that data is evenly distributed across different AZs. 
To achieve this, each node must be informed of its AZ by setting the `node.attr.zone: <ZONE>` property. 
This property tells OpenSearch which AZ the node belongs to, helping it optimize shard placement across the cluster.

To get this AZ information, we’ll use an init container that queries the Kubernetes API to fetch the AZ of the node where the pod is running. 
The AZ is then passed to OpenSearch at startup to configure shard allocation awareness.

{{< admonition info "Github issue" >}}
OpenSearch has reported an issue ([#664](https://github.com/opensearch-project/opensearch-k8s-operator/issues/664)) regarding this problem. Currently, passing availability zone (AZ) to the configuration is not yet implemented in the OpenSearch operator.
{{< /admonition >}}

# Setting availability zone for a pod
Setting up the Availability Zone for a pod using **OpenSearch's shard allocation awareness** as an example.

## Set permissions
To query the Kubernetes API for node information, we need to give the pod permission to access the node's metadata. 
This is done by setting up a `ClusterRole` and `ClusterRoleBinding` to allow access to the required resources.
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: opensearch-clusterrole
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get","list"]
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: opensearch-clusterrolebinding
subjects:
  - kind: ServiceAccount
    name: opensearch-sa
    namespace: opensearch
roleRef:
  kind: ClusterRole
  name: opensearch-clusterrole
  apiGroup: rbac.authorization.k8s.io
```
{{< admonition warning >}}
It needs to be a `ClusteRole`/`ClusterRoleBinding` instead of a `Role`/`RoleBinding`, as retrieving node metadata requires a cluster-level role.
{{< /admonition >}}

## Fetch availability zone
Now, we set up an init container to query the Kubernetes API and fetch the AZ where the pod is running. 
The init container stores the AZ in a file that will be used by the main OpenSearch container.

[Statefulset](https://github.com/kukulam/blog-code-materials/blob/main/posts/exposing-availability-zone-to-kubernetes-pods/manifests/statefulset.yaml) for OpenSearch
```yaml
      serviceAccountName: opensearch-sa
      initContainers:
        - name: init-az
          image: curlimages/curl:8.8.0
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          command:
            - /bin/sh
            - -c
            - |
              echo "Node name: $NODE_NAME"
              API_URL="https://kubernetes.default.svc/api/v1/nodes/$NODE_NAME"
              TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
              CA_CERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
              
              # Perform the HTTP request and capture the status code and body
              RESPONSE_FILE="/tmp/response.txt"
              RESPONSE=$(curl --write-out "HTTPSTATUS:%{http_code}" --silent --output $RESPONSE_FILE --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" $API_URL)

              # Extract the HTTP status code
              HTTP_STATUS=$(echo "$RESPONSE" | sed -e 's/.*HTTPSTATUS://')

              # Check if the status code is 200
              if [ "$HTTP_STATUS" -ne 200 ]; then
                echo "Failed to fetch node information. HTTP Status: $HTTP_STATUS"
                exit 1
              fi

              # Extract the az from label
              AZ=$(awk -F'"' '/topology.kubernetes.io\/zone/ {print $4}' $RESPONSE_FILE)

              echo "Node label 'topology.kubernetes.io/zone': $AZ"
              echo -n $AZ > /etc/opensearch/config/node-zone.txt
          volumeMounts:
            - name: az-config
              mountPath: /etc/opensearch/config/
            - name: kube-api-access
              mountPath: /var/run/secrets/kubernetes.io/serviceaccount
        ...
      volumes:
      - name: az-config
        emptyDir: {}
```
Here’s what’s happening in this init container:
- It retrieves the pod’s `NODE_NAME`.
- It performs an authenticated API request to Kubernetes to fetch the node metadata.
- The AZ information is extracted from the label `topology.kubernetes.io/zone` and stored in `/etc/opensearch/config/node-zone.txt` for use in the main container.

{{< admonition example "Init container logs" false >}}
```
Node name: opensearch-worker3
Node label 'topology.kubernetes.io/zone': us-east-1c
```
{{< /admonition >}}

## Pass the availability zone
Next, we configure the main OpenSearch container to read the AZ information from the file created by the init container and pass it as a flag during the OpenSearch startup process.

[Statefulset](https://github.com/kukulam/blog-code-materials/tree/main/exposing-availability-zone-to-kubernetes-pods/manifests/statefulset.yaml) for OpenSearch
```yaml
      containers:
        - name: opensearch
          image: opensearchproject/opensearch:2.15.0
          command:
            - sh
            - -c
            - "AZ=$(cat /etc/opensearch/config/node-zone.txt) && ./opensearch-docker-entrypoint.sh opensearch -Enode.attr.zone=${AZ} -Ecluster.routing.allocation.awareness.attributes=zone -Ecluster.routing.allocation.awareness.force.zone.values=us-east-1a,us-east-1b,us-east-1c "
```

Flag explanations:
1. **AZ=$(cat /etc/opensearch/config/node-zone.txt)**
   - This part reads the AZ value stored in the file /etc/opensearch/config/node-zone.txt (created by the init container) and stores it in the AZ variable. The file contains the zone in which the node is located (e.g., us-east-1a).
2. **-Enode.attr.zone=${AZ}**
   - This flag sets a custom attribute (node.attr.zone) in OpenSearch that identifies the AZ of the current node. The ${AZ} is dynamically set based on the value fetched from the file, so each pod gets the correct AZ information. OpenSearch uses this attribute for shard allocation awareness to ensure data is balanced across zones.
3. **-Ecluster.routing.allocation.awareness.attributes=zone**
   - This flag tells OpenSearch to enable awareness of the zone attribute during shard allocation. It instructs OpenSearch to consider the zone attribute (set by node.attr.zone) when making decisions about where to place data shards. This prevents shards from being placed in a single AZ, which could lead to data unavailability if an AZ goes down.
4. **-Ecluster.routing.allocation.awareness.force.zone.values=us-east-1a,us-east-1b,us-east-1c**
   - This flag explicitly defines the possible AZs (us-east-1a, us-east-1b, us-east-1c) that OpenSearch should take into account for shard placement. By providing this list, OpenSearch is aware of the available zones and ensures that shards are distributed across them. This enhances resiliency by ensuring that data is evenly spread across all zones in the cluster.

## Verify config
To confirm that the configuration was applied correctly, you can run the following query and check for availability zone awareness properties: 
```bash
curl -k -u $USERNAME:$PASSWORD https://localhost:9200/_cluster/settings?include_defaults=true&flat_settings=true

{
  ...
  "node.attr.shard_indexing_pressure_enabled": "true",
  "node.attr.zone": "us-east-1c",
  "node.data": "true",
  ...
  "cluster.routing.allocation.awareness.balance": "false",
  "cluster.routing.allocation.awareness.force.zone.values": "us-east-1a,us-east-1b,us-east-1c",
  "cluster.routing.allocation.balance.index": "0.55",
  ...
}
```
Key parameters to look for:
 - `node.attr.zone`: Indicates the specific AZ the node is located in (e.g., **us-east-1c**).
 - `cluster.routing.allocation.awareness.force.zone.values`: Lists the AZs (**us-east-1a**, **us-east-1b**, **us-east-1c**) that OpenSearch is aware of for distributing data across the cluster.

These values confirm that AZ awareness has been correctly configured for the cluster.

# Summary
In this post, we’ve demonstrated how to expose Availability Zone (AZ) information to Kubernetes pods using an init container. 
Although we used OpenSearch as an example, this approach can be applied to any application needing AZ-specific configurations. 
The key steps involve querying the Kubernetes API to fetch the AZ from node labels, storing it in a file, and then passing it to the application at startup.

# GitHub project
All files to setup OpenSearch are stored in [github repository](https://github.com/kukulam/blog-code-materials/tree/main/posts/exposing-availability-zone-to-kubernetes-pods).

# References
- OpenSearch 2.15 [documentation](https://opensearch.org/docs/2.15)
- OpenSearch operator's [Github issue](https://github.com/opensearch-project/opensearch-k8s-operator/issues/664)
- Photo by [NASA](https://unsplash.com/@nasa?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText") on [Unsplash](https://unsplash.com/photos/photo-of-outer-space-Q1p7bh3SHj8?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText")





