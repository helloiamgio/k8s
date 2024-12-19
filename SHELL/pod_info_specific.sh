#!/bin/bash

output_file="pod_info_specific.csv"

echo "Namespace,Pod,Container,Min Replicas,Max Replicas,CPU Request,CPU Limit,RAM Request,RAM Limit,HPA,CPU Utilization" > $output_file

# Modifica questa riga per includere i namespace specifici che desideri
namespaces=$(oc get ns --no-headers -o custom-columns=":metadata.name" | grep -E '^(3z|4b|o7|hn)')

for ns in $namespaces; do
  pods=$(oc get pods -n $ns --no-headers -o custom-columns=":metadata.name")
  
  for pod in $pods; do
    containers=$(oc get pod $pod -n $ns -o jsonpath='{.spec.containers[*].name}')
    
    for container in $containers; do
      cpu_request=$(oc get pod $pod -n $ns -o jsonpath="{.spec.containers[?(@.name=='$container')].resources.requests.cpu}")
      cpu_limit=$(oc get pod $pod -n $ns -o jsonpath="{.spec.containers[?(@.name=='$container')].resources.limits.cpu}")
      ram_request=$(oc get pod $pod -n $ns -o jsonpath="{.spec.containers[?(@.name=='$container')].resources.requests.memory}")
      ram_limit=$(oc get pod $pod -n $ns -o jsonpath="{.spec.containers[?(@.name=='$container')].resources.limits.memory}")
      
      deployment=$(oc get deployment -n $ns --no-headers -o custom-columns=":metadata.name" | grep -w $(echo $pod | cut -d'-' -f1))
      if [ -n "$deployment" ]; then
        min_replicas=$(oc get deployment $deployment -n $ns -o jsonpath='{.spec.replicas}')
      else
        min_replicas="N/A"
      fi
      
      hpa_names=$(oc get hpa -n $ns --no-headers -o custom-columns=":metadata.name" | grep -w $(echo $pod | cut -d'-' -f1) | tr '\n' '|')
      if [ -n "$hpa_names]"; then
        hpa_names=${hpa_names%|}
        max_replicas=$(oc get hpa -n $ns -o jsonpath="{.items[?(@.metadata.name=='$hpa_names')].spec.maxReplicas}" | tr '\n' '|')
        max_replicas=${max_replicas%|}
        cpu_utilization=$(oc get hpa -n $ns -o jsonpath="{.items[?(@.metadata.name=='$hpa_names')].spec.targetCPUUtilizationPercentage}" | tr '\n' '|')
        cpu_utilization=${cpu_utilization%|}
      else
        hpa_names="N/A"
        max_replicas="N/A"
        cpu_utilization="N/A"
      fi
      
      echo "$ns,$pod,$container,$min_replicas,$max_replicas,$cpu_request,$cpu_limit,$ram_request,$ram_limit,$hpa_names,$cpu_utilization" >> $output_file
    done
  done
done

echo "Informazioni sui pod scritte in $output_file"