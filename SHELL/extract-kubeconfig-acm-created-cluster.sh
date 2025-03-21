#!/bin/bash
# https://guifreelife.com/blog/2021/08/13/RHACM-Recover-Created-Cluster-Credentials-and-Kubeconfig/
#
# If an OpenShift cluster was created by RHACM this script will extract the
# kubeconfig and the default kubeadmin credentials.
#
# Prereqs:
# - Authenticated to hub cluster
# - Managed cluster name is the sames as the hosting namespace on hub cluster

# read cluster name from CLI
CLUSTER_NAME=${1}
mkdir -p $CLUSTER_NAME/auth

oc extract -n "$CLUSTER_NAME" \
     $(oc get secret -o name -n "$CLUSTER_NAME" \
          -l hive.openshift.io/cluster-deployment-name="$CLUSTER_NAME" \
          -l hive.openshift.io/secret-type=kubeconfig) \
     --to="$CLUSTER_NAME/auth/" \
     --confirm

oc extract -n "$CLUSTER_NAME" \
     $(oc get secret -o name -n "$CLUSTER_NAME" \
          -l hive.openshift.io/cluster-deployment-name="$CLUSTER_NAME" \
          -l hive.openshift.io/secret-type=kubeadmincreds ) \
     --to="$CLUSTER_NAME/auth/" \
     --confirm