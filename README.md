## **NAMESPACES/CONTEXT**

# use multiple kubeconfig files at the same time and view merged config
KUBECONFIG=~/.kube/config:~/.kube/kubconfig2
kubectl config view

# get the password for the e2e user
kubectl config view -o jsonpath='{.users[?(@.name == "e2e")].user.password}'

kubectl config view -o jsonpath='{.users[].name}'    # display the first user
kubectl config view -o jsonpath='{.users[*].name}'   # get a list of users
kubectl config get-contexts                          # display list of contexts
kubectl config current-context                       # display the current-context
kubectl config use-context my-cluster-name           # set the default context to my-cluster-name

kubectl config set-cluster my-cluster-name           # set a cluster entry in the kubeconfig

# configure the URL to a proxy server to use for requests made by this client in the kubeconfig
kubectl config set-cluster my-cluster-name --proxy-url=my-proxy-url

# add a new user to your kubeconf that supports basic auth
kubectl config set-credentials kubeuser/foo.kubernetes.com --username=kubeuser --password=kubepassword

# permanently save the namespace for all subsequent kubectl commands in that context.
kubectl config set-context --current --namespace=ggckad-s2

# set a context utilizing a specific username and namespace.
kubectl config set-context gce --user=cluster-admin --namespace=foo \
  && kubectl config use-context gce

kubectl config unset users.foo                       # delete user foo

# short alias to set/show context/namespace (only works for bash and bash-compatible shells, current context to be set before using kn to set namespace) 
alias kx='f() { [ "$1" ] && kubectl config use-context $1 || kubectl config current-context ; } ; f'
alias kn='f() { [ "$1" ] && kubectl config set-context --current --namespace $1 || kubectl config view --minify | grep namespace | cut -d" " -f6 ; } ; f'

### switch namespace senza kubens ###
kubectl config set-context $(kubectl config current-context) --namespace=<namespace>
kubectl config view | grep namespace
kubectl get pods

##### list alla namespace resources ####
kubectl api-resources --verbs=list --namespaced -o name   | xargs -n 1 kubectl get --show-kind --ignore-not-found -n tibco-prod

##### events sorted ##### 
kubectl get events --sort-by=.metadata.creationTimestamp

##### get quotas for all namespace ##### 
kubectl get quota --all-namespaces -o=custom-columns=Project:.metadata.namespace,TotalPods:.status.used.pods,TotalCPURequest:.status.used.requests'\.'cpu,TotalCPULimits:.status.used.limits'\.'cpu,TotalMemoryRequest:.status.used.requests'\.'memory,TotalMemoryLimit:.status.used.limits'\.'memory



[[[ DOCKER ]]]
##### identify log path #####
kubectl get pod pod-name -ojsonpath='{.status.containerStatuses[0].containerID}'
docker inspect container-id | grep -i logpath
