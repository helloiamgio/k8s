---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **POD**
### pod request/limits ###
kubectl get $i -o=jsonpath='{range .spec.containers[*]}{"Container Name: "}{.name}{"\n"}{"Requests:"}{.resources.requests}{"\n"}{"Limits:"}{.resources.limits}{"\n"}{end}' -n <NAMESPACE>
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{":\t"}{.spec.containers[0].resources.limits}{"\n"}{end}' 

### pod x nodo ###
kubectl get pods -o wide --all-namespaces | awk '{print $8}' | sort | uniq -c

### max pod x nodo ### 
kubectl get node <node_name> -ojsonpath='{.status.capacity.pods}{"\n"}'

### aprire shell in un pod ### 
kubectl exec -it --namespace=<NAMESPACE> <pod> -- bash (-c "mongo")

### describe pod with particular label ###
pod=$(kubectl get pods --selector="name=frontend" --output=jsonpath={.items..metadata.name})
kubectl describe pod $pod

### list only name ### 
kubectl get pods --no-headers -o custom-columns=":metadata.name"
kubectl get deploy --no-headers -o custom-columns=":metadata.name"

### list pod by restart ### 
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'

### list pod by age ### 
kubectl get pods --sort-by=.metadata.creationTimestamp

### list non running pod ###
kubectl get pods -A --field-selector=status.phase!=Running | grep -v Complete
kubectl get pod --field-selector status.phase!=Running -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,NAMEDPACE:.metadata.namespace

### list all container in a cluster ###
kubectl get pods -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .status.containerStatuses[*]}{.name}{": "}{.ready}{", "}{end}{end}'
kubectl get pod --all-namespaces | awk '{print $3}' | awk -F/ '{s+=$1} END {print s}' ### count

### get pods x nodes ### 
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=

### get pod using column ###
kubectl get pods --all-namespaces -o=custom-columns=NAME:.metadata.name,Namespace:.metadata.namespace

### list pod sort by name ###
kubectl get po -o wide --sort-by=.spec.nodeName

### which Pod is using which PVC ###
kubectl get po -o json --all-namespaces | jq -j '.items[] | "\(.metadata.namespace), \(.metadata.name), \(.spec.volumes[].persistentVolumeClaim.claimName)\n"' | grep -v null

### Pod termination message ###
kubectl get pod termination-demo -o go-template="{{range .status.containerStatuses}}{{.lastState.terminated.message}}{{end}}"

### delete evicted pods ### 
for POD in $(kubectl get pods|grep Evicted|awk '{print $1}'); do kubectl delete pods $POD ; done
kubectl get po -A --all-namespaces -o json | jq  '.items[] | select(.status.reason!=null) | select(.status.reason | contains("Evicted")) | "kubectl delete po \(.metadata.name) -n \(.metadata.namespace)"' | xargs -n 1 bash -c

### delete ALL Terminating pods ### 
kubectl get pods --all-namespaces | awk '$4=="Terminating" {print "kubectl delete pod --force --grace-period=0 --namespace="$1" "$2}'

### logs tail ### 
k logs -f NOMEPOD --tail=10

### logs degli ultimi x minuti ### 
k logs -f NOMEPOD --since=30m

### check reason for evicted pods ### 
kubectl get pod -A -o json | jq '.items##### #####  | select(.status.reason=="Evicted") | {NAME:.metadata.name, NAMESPACE:.metadata.namespace, REASON:.status.reason, MESSAGE:.status.message}'

### Produce ENV for all pods, assuming you have a default container for the pods, default namespace and the `env` command is supported. Helpful when running any supported command across all pods, not just `env` ###
for pod in $(kubectl get po --output=jsonpath={.items..metadata.name}); do echo $pod && kubectl exec -it $pod -- env; done

### Patch Image for a container ###
kubectl get pod/nginx -n default -o=custom-columns='IMAGE:spec.containers[*].image'
kubectl patch pod nginx -p '{"spec":{"containers":[{"name": "nginx","image": "nginx:1.9.6"}]}}'

### List pod with container images + node // Custom Column ###
kubectl get pod -o custom-columns="POD-NAME":.metadata.name,"NAMESPACE":.metadata.namespace,"CONTAINER-IMAGES":.spec.containers[*].image
#oc get pod -o custom-columns="POD-NAME":.metadata.name,"NAMESPACE":.metadata.namespace,"NODE":.spec.nodeName

### INTERACT with POD ###

kubectl logs my-pod                                 # dump pod logs (stdout)
kubectl logs -l name=myLabel                        # dump pod logs, with label name=myLabel (stdout)
kubectl logs my-pod --previous                      # dump pod logs (stdout) for a previous instantiation of a container
kubectl logs my-pod -c my-container                 # dump pod container logs (stdout, multi-container case)
kubectl logs -l name=myLabel -c my-container        # dump pod logs, with label name=myLabel (stdout)
kubectl logs my-pod -c my-container --previous      # dump pod container logs (stdout, multi-container case) for a previous instantiation of a container
kubectl logs -f my-pod                              # stream pod logs (stdout)
kubectl logs -f my-pod -c my-container              # stream pod container logs (stdout, multi-container case)
kubectl logs -f -l name=myLabel --all-containers    # stream all pods logs with label name=myLabel (stdout)
kubectl run -i --tty busybox --image=busybox:1.28 -- sh  # Run pod as interactive shell
kubectl run nginx --image=nginx -n mynamespace      # Start a single instance of nginx pod in the namespace of mynamespace
kubectl run nginx --image=nginx                     # Run pod nginx and write its spec into a file called pod.yaml
--dry-run=client -o yaml > pod.yaml

kubectl attach my-pod -i                            # Attach to Running Container
kubectl port-forward my-pod 5000:6000               # Listen on port 5000 on the local machine and forward to port 6000 on my-pod
kubectl exec my-pod -- ls /                         # Run command in existing pod (1 container case)
kubectl exec --stdin --tty my-pod -- /bin/sh        # Interactive shell access to a running pod (1 container case)
kubectl exec my-pod -c my-container -- ls /         # Run command in existing pod (multi-container case)
kubectl top pod POD_NAME --containers               # Show metrics for a given pod and its containers
kubectl top pod POD_NAME --sort-by=cpu              # Show metrics for a given pod and sort it by 'cpu' or 'memory'

kubectl cp /tmp/foo_dir my-pod:/tmp/bar_dir            # Copy /tmp/foo_dir local directory to /tmp/bar_dir in a remote pod in the current namespace
kubectl cp /tmp/foo my-pod:/tmp/bar -c my-container    # Copy /tmp/foo local file to /tmp/bar in a remote pod in a specific container
kubectl cp /tmp/foo my-namespace/my-pod:/tmp/bar       # Copy /tmp/foo local file to /tmp/bar in a remote pod in namespace my-namespace
kubectl cp my-namespace/my-pod:/tmp/foo /tmp/bar       # Copy /tmp/foo from a remote pod to /tmp/bar locally

kubectl logs mypod --since-time=2023-05-02T07:00:00Z --tail=100
kubectl logs <nome_pod> --timestamps | awk '/^[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2} 10:1[5-9]:|10:2[0-9]:/ {print}'

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## **NAMESPACES/CONTEXT**

### use multiple kubeconfig files at the same time and view merged config ###
KUBECONFIG=~/.kube/config:~/.kube/kubconfig2
kubectl config view

### get the password for the e2e user ###
kubectl config view -o jsonpath='{.users[?(@.name == "e2e")].user.password}'

kubectl config view -o jsonpath='{.users[].name}'    # display the first user
kubectl config view -o jsonpath='{.users[*].name}'   # get a list of users
kubectl config get-contexts                          # display list of contexts
kubectl config current-context                       # display the current-context
kubectl config use-context my-cluster-name           # set the default context to my-cluster-name

kubectl config set-cluster my-cluster-name           # set a cluster entry in the kubeconfig

### configure the URL to a proxy server to use for requests made by this client in the kubeconfig ###
kubectl config set-cluster my-cluster-name --proxy-url=my-proxy-url

### add a new user to your kubeconf that supports basic auth ###
kubectl config set-credentials kubeuser/foo.kubernetes.com --username=kubeuser --password=kubepassword

### permanently save the namespace for all subsequent kubectl commands in that context. ###
kubectl config set-context --current --namespace=ggckad-s2

### set a context utilizing a specific username and namespace. ###
kubectl config set-context gce --user=cluster-admin --namespace=foo \
  && kubectl config use-context gce

kubectl config unset users.foo                       # delete user foo

### short alias to set/show context/namespace (only works for bash and bash-compatible shells, current context to be set before using kn to set namespace) ### 
alias kx='f() { [ "$1" ] && kubectl config use-context $1 || kubectl config current-context ; } ; f'
alias kn='f() { [ "$1" ] && kubectl config set-context --current --namespace $1 || kubectl config view --minify | grep namespace | cut -d" " -f6 ; } ; f'

### switch namespace senza kubens ###
kubectl config set-context $(kubectl config current-context) --namespace=<namespace>
kubectl config view | grep namespace
kubectl get pods

### list alla namespace resources ###
kubectl api-resources --verbs=list --namespaced -o name   | xargs -n 1 kubectl get --show-kind --ignore-not-found -n tibco-prod

### get quotas for all namespace ###

kubectl get quota --all-namespaces -o=custom-columns=Project:.metadata.namespace,TotalPods:.status.used.pods,TotalCPURequest:.status.used.requests'\.'cpu,TotalCPULimits:.status.used.limits'\.'cpu,TotalMemoryRequest:.status.used.requests'\.'memory,TotalMemoryLimit:.status.used.limits'\.'memory

## **DOCKER**

### identify log path #####
kubectl get pod pod-name -ojsonpath='{.status.containerStatuses[0].containerID}'
docker inspect container-id | grep -i logpath

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## **EVENTS**

### get event sort by creation ###
kubectl get events --sort-by=.metadata.creationTimestamp

### get event filtered by type ###
kubectl get events --all-namespaces --field-selector type=Warning

### events sorted
kubectl get events --sort-by=.metadata.creationTimestamp

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


