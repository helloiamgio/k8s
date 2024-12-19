---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **KUBECTL**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

### Install ###
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl

chmod +x kubectl
mkdir -p ~/.local/bin
mv ./kubectl ~/.local/bin/kubectl

### Autocompletion ###
echo 'alias k=kubectl' >> ~/.bashrc ; 
echo 'source <(kubectl completion bash)' >> ~/.bashrc ; 
echo 'complete -F __start_kubectl k' >> ~/.bashrc ; 
echo 'source <(kubectl completion bash | sed 's/kubectl/k/g')' >> ~/.bashrc ; 
echo "source <(kubectl completion bash | sed 's|__start_kubectl kubectl|__start_kubectl ks|g') >> ~/.bashrc

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **POD**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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

### Delete Completed pods ### 
$ oc delete pod --field-selector=status.phase==Succeeded --all-namespaces
$ oc get pods --all-namespaces |  awk '{if ($4 == "Completed") system ("oc delete pod " $2 " -n " $1 )}'

### Additional methods to remove Failed, Pending, Evicted, and all 'Non-Running' pods: ###
$ oc delete pod --field-selector=status.phase==Failed --all-namespaces
$ oc delete pod --field-selector=status.phase==Pending --all-namespaces
$ oc delete pod --field-selector=status.phase==Evicted --all-namespaces
$ oc get pods --all-namespaces |  awk '{if ($4 != "Running") system ("oc delete pod " $2 " -n " $1 )}'

### Delete Evicted pods ### 
for POD in $(kubectl get pods|grep Evicted|awk '{print $1}'); do kubectl delete pods $POD ; done
kubectl get po -A --all-namespaces -o json | jq  '.items[] | select(.status.reason!=null) | select(.status.reason | contains("Evicted")) | "kubectl delete po \(.metadata.name) -n \(.metadata.namespace)"' | xargs -n 1 bash -c

### Delete ALL Terminating pods ### 
kubectl get pods --all-namespaces | awk '$4=="Terminating" {print "kubectl delete pod --force --grace-period=0 --namespace="$1" "$2}'

### logs tail ### 
k logs -f NOMEPOD --tail=10

### logs degli ultimi x minuti ### 
k logs -f NOMEPOD --since=30m

### Check reason for evicted pods ### 
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

kubectl logs my-pod                                 
kubectl logs -l name=myLabel                        
kubectl logs my-pod --previous                      
kubectl logs my-pod -c my-container                 
kubectl logs -l name=myLabel -c my-container        
kubectl logs my-pod -c my-container --previous      
kubectl logs -f my-pod                              
kubectl logs -f my-pod -c my-container              
kubectl logs -f -l name=myLabel --all-containers    
kubectl run -i --tty busybox --image=busybox:1.28 -- sh
kubectl run nginx --image=nginx -n mynamespace
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml

kubectl attach my-pod -i
kubectl port-forward my-pod 5000:6000
kubectl exec my-pod -- ls / 
kubectl exec --stdin --tty my-pod -- /bin/sh
kubectl exec my-pod -c my-container -- ls /
kubectl top pod POD_NAME --containers
kubectl top pod POD_NAME --sort-by=cpu
kubectl top pod POD_NAME --sort-by=memory

kubectl cp /tmp/foo_dir my-pod:/tmp/bar_dir
kubectl cp /tmp/foo my-pod:/tmp/bar -c my-container
kubectl cp /tmp/foo my-namespace/my-pod:/tmp/bar
kubectl cp my-namespace/my-pod:/tmp/foo /tmp/bar

kubectl logs mypod --since-time=2023-05-02T07:00:00Z --tail=100
kubectl logs <nome_pod> --timestamps | awk '/^[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2} 10:1[5-9]:|10:2[0-9]:/ {print}'

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **NAMESPACES/CONTEXT**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **EVENTS**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### get event sort by creation ###
kubectl get events --sort-by=.metadata.creationTimestamp

### get event filtered by type ###
kubectl get events --all-namespaces --field-selector type=Warning

### events sorted
kubectl get events --sort-by=.metadata.creationTimestamp

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **DEPLOY**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### restart pod graceful ### 
k get deploy
k rollout restart deployment ncp-3ds

### change Deployment Image ###
kubectl set image deployment/application app-container=$IMAGE

### ROLLOUT RESTART under 1.15 kubectl  ###
kubectl patch deployment NOMEDEPLOY -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"date\":\"`date +'%s'`\"}}}}}"

### restart updating dummy ENV ### 
kubectl set env deploy/<DEPLOY> MYVAR=$(date)

### RESTART ALL DEPLOYMENT in THE CLUSTER ###
kubectl get deployments --all-namespaces | tail +2 | awk '{ cmd=sprintf("kubectl rollout restart deployment -n %s %s", $1, $2) ; system(cmd) }'

### RESTART ALL DEPLOYMENT in a NAMESPACE ###
kubectl get deployments -n 2a-cil -o custom-columns=NAME:.metadata.name|grep -iv NAME|while read LINE; do kubectl rollout restart deployment $LINE -n 2a-cil ; done

### SCALE DOWN ###
cat all_deployment.txt | grep -v "0/0" | grep -v NAME | grep -v kube-system | grep -v istio-system | while read ns dep more ; do kubectl scale deployment $dep -n $ns --replicas=0; done

### SCALE UP ###
cat all_deployment.txt | grep -v "0/0" | grep -v NAME | grep -v istio-system | grep -v kube-system | while read ns dep rep more; do replica=$(echo $rep | cut -f2 -d "/"); kubectl scale deployment $dep -n $ns --replicas=$replica; done

### Retrieve Original Replicas ###
replica_spec=$(kubectl get deployment/applicatiom -o jsonpath='{.spec.replicas}')
kubectl scale --replicas=0 deployment application
kubectl scale --replicas=$replica_spec deployment application

### BACKUP DEPLOY ### 
for i in $(kubectl get deployments --no-headers -o custom-columns=":metadata.name"); do k get deploy $i -o yaml > $i-deploy.yaml; done

### SET RESOURCES DEPLOY ### 
kubectl set resources deployment nginx --limits cpu=200m,memory=512Mi --requests cpu=100m,memory=256Mi

### REMOVE RESOURCES DEPLOY ### 
kubectl set resources deployment nginx --limits cpu=0,memory=0 --requests cpu=0,memory=0

### UPDATE RESOURCES DEPLOY ### 
kubectl patch deployment velero -n velero --patch \
'{"spec":{"template":{"spec":{"containers":[{"name": "velero", "resources": {"limits":{"cpu": "1", "memory": "512Mi"}, "requests": {"cpu": "1", "memory": "128Mi"}}}]}}}}'

### ROLLOUT DEPLOY ### 
kubectl rollout status deployment nginx

kubectl rollout pause deployment nginx
kubectl rollout resume deployment nginx
kubectl rollout history deployment nginx
kubectl rollout undo deployments nginx (--to-revision 3)

### Disable a deployment livenessProbe using a json patch with positional arrays ###
kubectl patch deployment valid-deployment  --type json   -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/livenessProbe"}]'

### PATCH Image Policy ###
kubectl get deployments -o name | sed -e 's/.*\///g' | xargs -I {} kubectl patch deployment {} --type=json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "IfNotPresent"}]'

### PATCH ImagePullSecret ###
kubectl patch deployment my-deployment -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"my-secret-pull"}]}}}}'

### Restart ALL DEPLOY in a namespace ###
kubectl get deployments -n <NAMESPACE> -o custom-columns=NAME:.metadata.name|grep -iv NAME|while read LINE; do kubectl rollout restart deployment $LINE -n <NameSpace Name> ; done;
kubectl rollout restart deployment -n <NAMESPACE>

### Per ogni nome di deployment, stampa le immagini dei relativi container ###
for deployment_name in $deployment_names; do
    container_names=$(kubectl get deployment $deployment_name -o=jsonpath='{.spec.template.spec.containers[*].name}')
    for container_name in $container_names; do
        image=$(kubectl get deployment $deployment_name -o=jsonpath="{.spec.template.spec.containers[?(@.name=='$container_name')].image}")
        echo "Deployment: $deployment_name - Container: $container_name - Immagine: $image"
    done
done

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **AFFINITY/NODESELECTOR/LABEL*
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

kubectl run newpod --image image1 --overrides='{ "spec": { "affinity": { "nodeAffinity": { "requiredDuringSchedulingIgnoredDuringExecution": { "nodeSelectorTerms": [{ "matchExpressions": [{ "key": "kubernetes.io/hostname",  "operator": "In", "values": [ "one-worker-node", "second-worker-node" ]} ]} ]} } } } }'

### aggiungere label ai nodi ###
kubectl label nodes grpi-kb1-kv21 app=invydio

### aggiungere label a tutti i nodi ###
kubectl label nodes --all -app=invydio

### rimuovere label ###
kubectl label nodes --all app-

### patch deployment ###
kubectl patch deployment my-deployment -p '{"spec":{"template":{"spec":{"nodeSelector":{"app":"apphub"}}}}}'
kubectl patch deployment my-deployment -p '{"spec":{"template":{"spec":{"nodeSelector":{"node-role.kubernetes.io/worker":"true"}}}}}'

### remove ###
kubectl patch deployment <nome-del-tuo-deployment> --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/node-role.kubernetes.io~1worker"}]'

### replace ###
kubectl patch deployment <nome-del-tuo-deployment> --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/nodeSelector", "value": {"app": "apphub"}}]'

### list nodeselector ###
kubectl get deployment my-deployment -o jsonpath={.spec.template.spec.nodeSelector}

### Funzione per stampare il valore delle label dei pod ###
stampare_valore_label_pod() {
    namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
    kubectl get pods --namespace=$namespace -o=jsonpath='{range .items[*]}{"Namespace: "}{.metadata.namespace}{"\nPod Name: "}{.metadata.name}{"\nLabel: "}{.metadata.labels}{"\n\n"}'
}

### Funzione per eseguire una ricerca con una label specifica ###

read -p "Inserisci la label nel formato label:valore: " label
label_key=$(echo $label | cut -d ":" -f 1)
label_value=$(echo $label | cut -d ":" -f 2)
kubectl get pods --namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}') -l "$label_key"="$label_value" -o wide

### Funzione per visualizzare i nodeselector dei deployment ###

kubectl get deployments --namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}') -o=jsonpath='{range .items[*]}{"\n\nDeployment Name: "}{.metadata.name}{"\nNamespace: "}{.metadata.namespace}{"\nNodeSelector: "}{.spec.template.spec.nodeSelector}{"\n"}'

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **NODES**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### ALLOCAZIONE RISORSE ###
alias util='kubectl get nodes --no-headers | awk '\''{print $1}'\'' | xargs -I {} sh -c '\''echo {} ; kubectl describe node {} | grep Allocated -A 5 | grep -ve Event -ve Allocated -ve percent -ve -- ; echo '\'''
util

### label node ### 
kubectl node <node-name> kubernets.io/role=<name-your-node-role> ##### --overwrite ##### 
es. kubectl label node worker1  node-role.kubernetes.io/worker=worker

### patch node selector ### 
kubectl patch deployments nginx-deployment -p '{"spec": {"template": {"spec": {"nodeSelector": {"kubernetes.io/hostname": "node-2"}}}}}'

### check Taints ###
kubectl get nodes <NODE> -o json | jq -r '.spec.taints | .[]'

### get node info columns ###
kubectl get nodes -o custom-columns="Name:.metadata.name,InternalIP:.status.addresses[0].address"
kubectl get nodes -o custom-columns="Name:.metadata.name,InternalIP:.status.addresses[0].address,Kernel:.status.nodeInfo.kernelVersion,MemoryPressure:.status.conditions[0].status,DiskPressure:.status.conditions[1].status,PIDPressure:.status.conditions[2].status,Ready:.status.conditions[3].status"

kubectl cordon my-node                                                # Mark my-node as unschedulable
kubectl drain my-node                                                 # Drain my-node in preparation for maintenance
kubectl uncordon my-node                                              # Mark my-node as schedulable
kubectl top node my-node                                              # Show metrics for a given node
kubectl cluster-info                                                  # Display addresses of the master and services
kubectl cluster-info dump                                             # Dump current cluster state to stdout
kubectl cluster-info dump --output-directory=/path/to/cluster-state   # Dump current cluster state to /path/to/cluster-state

### View existing taints on which exist on current nodes. ###
kubectl get nodes -o=custom-columns=NodeName:.metadata.name,TaintKey:.spec.taints[*].key,TaintValue:.spec.taints[*].value,TaintEffect:.spec.taints[*].effect

### If a taint with that key and effect already exists, its value is replaced as specified. ###
kubectl taint nodes foo dedicated=special-user:NoSchedule

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **SERVICE**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### change type to NodePort ###
kubectl patch svc prometheus-grafana --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"}]' -n kube-prometheus-stack
kubectl patch svc prometheus-grafana --type='json' -p '[{"op": "add", "path":"/spec/ports/0/nodePort", "value":33333}]' -n kube-prometheus-stack

### change type to ClusterIP ###
kubectl patch service prometheus-kube-prometheus-prometheus -n kube-prometheus-stack -p '{"spec": {"type": "ClusterIP"}}'

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **CRONJOB**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### execute jobs immediately ### 
kubectl get cronjob -n offloading
kubectl create job --from=cronjob/<cronjob-name> <job-name> -n offloading

kubectl get pods -n offloading
kubectl delete job <job-name>
kubectl delete pods/nomepod -n offloading

### patch cronjob schedule ### 
kubectl patch cronjobs <job-name> -p '{"spec" : {"suspend" : true }}'

### suspend active cronjobs ###
kubectl get cronjob | grep False | awk '{print $1}' | xargs kubectl patch cronjob -p '{"spec" : {"suspend" : true }}'

### resume suspended cronjobs ###
kubectl get cronjob | grep True | awk '{print $1}' | xargs kubectl patch cronjob -p '{"spec" : {"suspend" : false }}'

### LOOP ###
for CJ in $(k get cj -A | grep ocr | awk '{print $2}'); do k patch cj $CJ -p '{"spec" : {"suspend" : true }}'; done
for CJ in $(k get cj -A | grep ocr | awk '{print $2}'); do k patch cj $CJ -p '{"spec" : {"suspend" : false }}'; done

### recreate cronjob ###  
for CJ in $(k get cj -A | grep ocr | awk '{print $2}'); do k get cj $CJ -o yaml > $CJ.backup.yaml; done
for CJ in $(k get cj -A | grep ocr | awk '{print $2}'); do k delete cj $CJ ; done
for CJ in $(ls -1 *.yaml); do k create -f $CJ.backup.yaml ; done

### create a Job which prints "Hello World" ###
kubectl create job hello --image=busybox:1.28 -- echo "Hello World"

### create a CronJob that prints "Hello World" every minute ###
kubectl create cronjob hello --image=busybox:1.28   --schedule="*/1 * * * *" -- echo "Hello World"

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **IMAGES**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### list all images for pod ###
kubectl get pods -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' | sort

kubectl get pods -o jsonpath="{.items[*].spec.containers[*].image}"

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **DAEMONSET**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### Scaling k8s daemonset down to zero ### 
kubectl -n <namespace> patch daemonset <name-of-daemon-set> -p '{"spec": {"template": {"spec": {"nodeSelector": {"non-existing": "true"}}}}}'

### Scaling up k8s daemonset ### 
kubectl -n <namespace> patch daemonset <name-of-daemon-set> --type json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/non-existing"}]'

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **SECRET**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### Print secrets in clear base64 ###
kubectl get secret my-secret -o 'go-template={{index .data "username"}}' | base64 -d
kubectl get secret my-secret -o json | jq '.data | map_values(@base64d)'

### update with patch ###
kubectl patch secret test --type='json' -p='[{"op" : "replace" ,"path" : "/data/username" ,"value" : "dGVzdHVzZXIy"}]'

### Create a secret with several keys ###
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  password: $(echo -n "s33msi4" | base64 -w0)
  username: $(echo -n "jane" | base64 -w0)
EOF

### Output decoded secrets without external tools ###
kubectl get secret my-secret -o go-template='{{range $k,$v := .data}}{{"### "}}{{$k}}{{"\n"}}{{$v|base64decode}}{{"\n\n"}}{{end}}'

### List all Secrets currently in use by a pod ###
kubectl get pods -o json | jq '.items[].spec.containers[].env[]?.valueFrom.secretKeyRef.name' | grep -v null | sort | uniq

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **CONFIGMAP**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### extract file from configmap ###
kubectl get cm <NOME-CONFIGMAP> -o jsonpath='{.data.ballerina\.conf}' > ballerina.conf
kubectl get cm 3-2-0-wso2apim-gw-worker-conf -o template='{{ index .data "deployment.toml" }}'

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **RBAC**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### Check to see if I can do everything in my current namespace ("*" means all) ###
kubectl auth can-i '*' '*'

### Check to see if I can create pods in any namespace ###
kubectl auth can-i create pods --all-namespaces

###  Check to see if I can list deployments in my current namespace ###
kubectl auth can-i list deployments.extensions

### Check permission for account ###
kubectl auth can-i get pods --as=system:serviceaccount:default:default
kubectl auth can-i --list

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **STORAGECLASS**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### set sc as default
kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' && kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **PVC**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### resize PVC ###
$newsize='{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"<newsize>Gi\"}}}}'
kubectl patch pvc <name of PVC> --namespace <namespace> --type merge --patch $newsize

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **SCC**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### get pod scc ###

kubectl get pods -n ping -o go-template --template='{{range .items}}{{"pod: "}}{{.metadata.name}}
    {{if .spec.securityContext}}
      PodSecurityContext:
        {{"runAsGroup: "}}{{.spec.securityContext.runAsGroup}}                               
        {{"runAsNonRoot: "}}{{.spec.securityContext.runAsNonRoot}}                           
        {{"runAsUser: "}}{{.spec.securityContext.runAsUser}}                                 {{if .spec.securityContext.seLinuxOptions}}
        {{"seLinuxOptions: "}}{{.spec.securityContext.seLinuxOptions}}                       {{end}}
    {{else}}PodSecurity Context is not set
    {{end}}{{range .spec.containers}}
    {{"container name: "}}{{.name}}
    {{"image: "}}{{.image}}{{if .securityContext}}                                      
        {{"allowPrivilegeEscalation: "}}{{.securityContext.allowPrivilegeEscalation}}   {{if .securityContext.capabilities}}
        {{"capabilities: "}}{{.securityContext.capabilities}}                           {{end}}
        {{"privileged: "}}{{.securityContext.privileged}}                               {{if .securityContext.procMount}}
        {{"procMount: "}}{{.securityContext.procMount}}                                 {{end}}
        {{"readOnlyRootFilesystem: "}}{{.securityContext.readOnlyRootFilesystem}}       
        {{"runAsGroup: "}}{{.securityContext.runAsGroup}}                               
        {{"runAsNonRoot: "}}{{.securityContext.runAsNonRoot}}                           
        {{"runAsUser: "}}{{.securityContext.runAsUser}}                                 {{if .securityContext.seLinuxOptions}}
        {{"seLinuxOptions: "}}{{.securityContext.seLinuxOptions}}                       {{end}}{{if .securityContext.windowsOptions}}
        {{"windowsOptions: "}}{{.securityContext.windowsOptions}}                       {{end}}
    {{else}}
        SecurityContext is not set
    {{end}}
{{end}}{{end}}'

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## **DOCKER**
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### identify log path #####
kubectl get pod pod-name -ojsonpath='{.status.containerStatuses[0].containerID}'
docker inspect container-id | grep -i logpath

### Immagini docker per size ###
docker images --format 'table {{.Repository}}\t{{.ID}}\t{{.Tag}}\t{{.Size}}' | (read -r; printf "%s\n" "$REPLY"; sort -h -k7)

### show labels ###
docker container ls --format "table {{.ID}}\t{{.Labels}}" 
docker image ls -a --filter "not label=com.docker.ucp.version=3.5.3"
docker image prune --filter label!=com.docker.dtr.version: 2.9.7

### prune with label ###
docker image prune --filter label!=com.docker.ucp.version=3.5.3 --filter label!=com.docker.dtr.version:2.9.7

### Running images ###
runningImages=$(docker ps --format {{.Image}})
docker images --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep -v "$runningImages"

### container IP ###
docker ps --format "{{.Names}}" | while read name; do echo "$name: $(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $name)"; done

### set proxy ###
mkdir /etc/systemd/system/docker.service.d ; cd /etc/systemd/system/docker.service.d


cat <<EOF > http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://user01:password@10.10.10.10:8080/"
Environment="HTTPS_PROXY=https://user01:password@10.10.10.10:8080/"
Environment="NO_PROXY= hostname.example.com,172.10.10.10"
EOF

systemctl daemon-reload
systemctl restart docker

systemctl show docker --property Environment 

removecontainers() {
    docker stop $(docker ps -aq)
    docker rm $(docker ps -aq)
}

### clean ###
armageddon() {
    removecontainers
    docker network prune -f
    docker rmi -f $(docker images --filter dangling=true -qa)
    docker volume rm $(docker volume ls --filter dangling=true -q)
    docker rmi -f $(docker images -qa)
}

docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' | grep 'imagename')
docker rmi $(docker images --filter=reference="IMAGENAME:TAG")

### cartelle container su fs ###
docker inspect -f $'{{.Name}}\t{{.GraphDriver.Data.MergedDir}}' $(docker ps -aq)

### get container ID ###
kubectl get pods -o wide -n offloading-coll --field-selector spec.nodeName=grpi-kb1-kv31  -o json | jq -r '.items[].status.containerStatuses[].containerID' | tr -d 'docker://'

