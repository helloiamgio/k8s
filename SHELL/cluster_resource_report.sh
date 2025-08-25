#!/bin/bash

# File di output
OUTPUT_FILE="cluster_resource_report_$(date +%Y%m%d_%H%M%S).txt"
echo "Generating full cluster resource report..." | tee $OUTPUT_FILE
echo "Report generated on: $(date)" >> $OUTPUT_FILE
echo "==========================================" >> $OUTPUT_FILE

# 1 Allocated resources per node
echo -e "\n=== NODE ALLOCATED RESOURCES ===" | tee -a $OUTPUT_FILE
oc describe nodes | grep -A5 "Allocated resources" >> $OUTPUT_FILE

# 2 Node usage (top)
echo -e "\n=== NODE USAGE (oc adm top nodes) ===" | tee -a $OUTPUT_FILE
oc adm top nodes >> $OUTPUT_FILE

# 3 ResourceQuota per namespace
echo -e "\n=== RESOURCE QUOTAS PER NAMESPACE ===" | tee -a $OUTPUT_FILE
for ns in $(oc get ns -o jsonpath='{.items[*].metadata.name}'); do
    rq_count=$(oc get resourcequota -n $ns --no-headers 2>/dev/null | wc -l)
    if [ "$rq_count" -gt 0 ]; then
        echo -e "\n--- Namespace: $ns ---" >> $OUTPUT_FILE
        oc get resourcequota -n $ns -o wide >> $OUTPUT_FILE
        for rq in $(oc get resourcequota -n $ns -o jsonpath='{.items[*].metadata.name}'); do
            echo "Details for ResourceQuota: $rq" >> $OUTPUT_FILE
            oc describe resourcequota $rq -n $ns >> $OUTPUT_FILE
        done
    fi
done

# 4 Pod requests/limits per namespace
echo -e "\n=== POD RESOURCES PER NAMESPACE ===" | tee -a $OUTPUT_FILE
for ns in $(oc get ns -o jsonpath='{.items[*].metadata.name}'); do
    pod_count=$(oc get pods -n $ns --no-headers 2>/dev/null | wc -l)
    if [ "$pod_count" -gt 0 ]; then
        echo -e "\n--- Namespace: $ns ---" >> $OUTPUT_FILE
        oc get pods -n $ns -o custom-columns=NAME:.metadata.name,CPU_REQUEST:.spec.containers[*].resources.requests.cpu,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEM_REQUEST:.spec.containers[*].resources.requests.memory,MEM_LIMIT:.spec.containers[*].resources.limits.memory >> $OUTPUT_FILE
    fi
done

# 5 Total usage per namespace (summary)
echo -e "\n=== TOTAL RESOURCE REQUESTS & LIMITS PER NAMESPACE ===" | tee -a $OUTPUT_FILE
for ns in $(oc get ns -o jsonpath='{.items[*].metadata.name}'); do
    total_cpu_request=$(oc get pods -n $ns -o jsonpath='{range .items[*].spec.containers[*]}{.resources.requests.cpu}{" "}{end}' | tr ' ' '\n' | grep -v '^$' | awk '{s+=$1} END {print s+0}')
    total_mem_request=$(oc get pods -n $ns -o jsonpath='{range .items[*].spec.containers[*]}{.resources.requests.memory}{" "}{end}' | tr ' ' '\n' | grep -v '^$' | awk '{s+=$1} END {print s+0}')
    total_cpu_limit=$(oc get pods -n $ns -o jsonpath='{range .items[*].spec.containers[*]}{.resources.limits.cpu}{" "}{end}' | tr ' ' '\n' | grep -v '^$' | awk '{s+=$1} END {print s+0}')
    total_mem_limit=$(oc get pods -n $ns -o jsonpath='{range .items[*].spec.containers[*]}{.resources.limits.memory}{" "}{end}' | tr ' ' '\n' | grep -v '^$' | awk '{s+=$1} END {print s+0}')
    echo "$ns: CPU_REQUEST=$total_cpu_request, CPU_LIMIT=$total_cpu_limit, MEM_REQUEST=$total_mem_request, MEM_LIMIT=$total_mem_limit" >> $OUTPUT_FILE
done

echo -e "\nReport saved in $OUTPUT_FILE"

