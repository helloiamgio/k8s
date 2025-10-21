# ALB + Kubernetes (Ingress) — Guida completa

> Guida completa pronta da copiare/incollare (.md). Spiega come funziona il flusso di traffico quando usi un **AWS Application Load Balancer (ALB)** con Kubernetes / OpenShift tramite **AWS Load Balancer Controller / Operator**, le opzioni principali, manifest YAML di esempio per i casi più comuni, comandi di debug, raccomandazioni e troubleshooting. Il contenuto è generico e non riferito a un caso specifico.

---

## Indice

1. Introduzione: cosa fa l’ALB Controller/Operator
2. Concetti chiave e termini
3. Architetture / flussi di traffico (diagrammi)
4. Modalità di target del Target Group: `instance` vs `ip`
5. `externalTrafficPolicy`: `Cluster` vs `Local` (comportamento e impatto)
6. Come il controller aggiorna TargetGroup e perché
7. Annotazioni ALB importanti (lista e significato)
8. YAML di esempio (Deployment + Service + Ingress) — varianti pronte
9. Installazione e prerequisiti del controller/operator (generico)
10. Comandi utili per debug (Kubernetes + AWS CLI)
11. Health checks, access logs e metriche
12. Troubleshooting comune (cause e soluzioni)
13. Best practices e limiti da tenere in conto
14. Checklist rapida per deploy in un cluster vuoto
15. Appendice: comandi e snippet utili

---

## 1) Introduzione

L’**AWS Load Balancer Controller** (o Operator su OpenShift/ROSA) osserva oggetti Kubernetes (`Ingress`, `Service`, `EndpointSlice`/`Endpoints`) e crea/configura risorse AWS (ALB, Target Groups, Listeners, Rules) per esporre le applicazioni. L’`Ingress` definisce le regole; il controller le traduce in oggetti AWS.

Scopo di questa guida:
- spiegare i concetti e il flusso del traffico
- mostrare le opzioni più usate e quando sceglierle
- fornire manifest YAML di esempio pronti all'uso
- fornire comandi per debug e troubleshooting

---

## 2) Concetti chiave

- **ALB (Application Load Balancer)**: bilanciatore a livello applicazione (HTTP/HTTPS) su AWS.
- **Target Group (TG)**: insieme di target (istanze EC2 o indirizzi IP) che ricevono il traffico dal ALB.
- **Target Type**:
  - `instance` → target sono ID delle EC2 (nodi).
  - `ip` → target sono indirizzi IP (es. IP dei pod o ENI).
- **NodePort**: porta esposta da Kubernetes su ogni nodo; usata se controller registra le istanze (instance).
- **externalTrafficPolicy**:
  - `Cluster` → il NodePort è presente su tutti i nodi; kube-proxy può inoltrare traffico verso pod su altri nodi.
  - `Local` → il NodePort è attivo solo sui nodi che hanno pod del service, preserva l’IP sorgente.
- **Endpoint / EndpointSlice**: informazioni su IP dei pod back-end; usate dal controller per aggiornare TG se target-type=ip.
- **IngressClass**: `alb` o altro; indica al controller quale controller deve processare l’Ingress.

---

## 3) Architetture / flussi di traffico (diagrammi ASCII)

### A) `instance` + `externalTrafficPolicy: Cluster` (comportamento tollerante)
```
Client -> ALB DNS
         ALB TG (targets = worker EC2:NodePort)
            -> Node X (nodePort 30080) -- kube-proxy --> Pod (su Node Y: podIP:8080)
```
- ALB manda traffico a ogni nodo registrato; kube-proxy inoltra ai pod indipendentemente dal nodo su cui risiedono.

### B) `instance` + `externalTrafficPolicy: Local`
```
Client -> ALB DNS
         ALB TG (targets = solo nodi con pod locali)
            -> Node Y (local) -> Pod on Node Y
```
- Controller registra solo i nodi che hanno endpoints locali. Se il pod si sposta, il TG viene aggiornato.

### C) `ip` (target direttamente su IP dei pod)
```
Client -> ALB DNS
         ALB TG (targets = pod IPs)
            -> Pod IP (10.x.x.x) on Node Y
```
- Controller registra direttamente gli IP dei pod nel TG; quando il pod cambia IP, il TG viene aggiornato.

---

## 4) `instance` vs `ip` — pro/contro

### `instance` (targetType = instance)
**Pro**:
- Semplice e robusto: ALB manda traffico ai nodi.
- Se `externalTrafficPolicy=Cluster`, il movimento dei pod è trasparente.
- Meno aggiornamenti al TG.

**Contro**:
- Non preserva IP sorgente client a meno che non si usi `Local`.
- Se `Local`, i TG possono cambiare frequentemente a seconda dei pod.

### `ip` (targetType = ip)
**Pro**:
- Target diretto sui pod; routing più preciso.
- Maggiore visibilità sui singoli pod come target.

**Contro**:
- Aggiornamenti TG più frequenti (ogni ricreazione pod).
- Limiti AWS sul numero di target per TG.
- Richiede networking (CNI) che consenta ALB→IP pod reachability. Potrebbe essere necessario configurare security groups/ENI.

---

## 5) `externalTrafficPolicy`: `Cluster` vs `Local`

- **Cluster**:
  - NodePort è attivo su tutti i nodi.
  - Kube-proxy può inoltrare traffico ai pod su altri nodi.
  - Non preserva client source IP a meno di ulteriori configurazioni (es. proxy protocol).
  - ALB non deve aggiornare i target quando i pod si spostano.

- **Local**:
  - NodePort è attivo solo sui nodi che hanno pod per quel service.
  - Preserva client source IP.
  - Controller registra solo nodi con endpoints locali; al cambiamento di pod, ALB/Controller aggiorna la membership del TG.

Scelta consigliata:
- `Cluster` per semplicità e resilienza.
- `Local` se hai bisogno del client source IP e puoi tollerare aggiornamenti del TG.

---

## 6) Come e quando il controller aggiorna Target Group

Il controller osserva questi oggetti:
- `Ingress` (regole e annotazioni)
- `Service` (type, NodePort, externalTrafficPolicy)
- `Endpoints` / `EndpointSlices` (IP dei pod)
- Stato dei nodi

Decisione logica (semplificata):
- Se `target-type=instance`:
  - con `externalTrafficPolicy=Cluster` → il controller registra (tipicamente) tutti i nodi worker (porta = NodePort) come target.
  - con `externalTrafficPolicy=Local` → registra solo i nodi che hanno endpoint locali; quando gli endpoints cambiano, chiama `RegisterTargets`/`DeregisterTargets` su AWS.
- Se `target-type=ip`:
  - registra direttamente gli IP presi dagli `EndpointSlices`/`Endpoints` nel Target Group.

Il controller chiama le API AWS (ELBV2) per aggiornare i Target Group quando necessario.

---

## 7) Annotazioni ALB importanti (esempi e significato)

> Nota: la lista può variare fra versioni del controller/operator; controlla la documentazione specifica.

- `alb.ingress.kubernetes.io/scheme: internal|internet-facing` — ALB interno o pubblico.
- `alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'` — listener ports.
- `alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...` — certificato per HTTPS.
- `alb.ingress.kubernetes.io/target-type: instance|ip` — tipo di target del TG.
- `alb.ingress.kubernetes.io/backend-protocol: HTTP|HTTPS` — protocollo verso backend.
- `alb.ingress.kubernetes.io/rewrite-target: /` — rewrite path (se supportato dall’implementazione).
- `alb.ingress.kubernetes.io/healthcheck-path: /health` — health check path.
- `alb.ingress.kubernetes.io/healthcheck-port: traffic-port|80` — health check port.
- `alb.ingress.kubernetes.io/healthcheck-protocol: HTTP|HTTPS` — health check protocol.
- `alb.ingress.kubernetes.io/healthcheck-interval-seconds: "30"`
- `alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"`
- `alb.ingress.kubernetes.io/healthcheck-success-threshold: "2"`
- `alb.ingress.kubernetes.io/healthcheck-failure-threshold: "2"`
- `alb.ingress.kubernetes.io/subnets: subnet-a,subnet-b,subnet-c` — subnet dove creare ALB (opzionale se controller gestisce automaticamente).
- `alb.ingress.kubernetes.io/security-groups: sg-xxx,sg-yyy` — security group per ALB ENI.
- `alb.ingress.kubernetes.io/success-codes` — custom success codes per healthcheck.
- `alb.ingress.kubernetes.io/ssl-redirect: '443'` o `alb.ingress.kubernetes.io/force-ssl-redirect: 'true'` — redirect HTTP→HTTPS.
- `alb.ingress.kubernetes.io/group.name` / `alb.ingress.kubernetes.io/group.order` — per raggruppare ingress (se supportato dal controller).

---

## 8) YAML di esempio (copiabili)

> Tutti gli esempi sono generici. Adatta host, nomi, immagini, certificate-arn, subnets e security groups al tuo ambiente.

### 8.1) Deployment di esempio
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: nginx:stable
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
```

### 8.2) Variante A — `instance` + `externalTrafficPolicy: Cluster` (default, tollerante)
Service:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  type: NodePort
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
    # nodePort: 30080   # opzionale, altrimenti k8s assegna un nodePort
  externalTrafficPolicy: Cluster
```
Ingress:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
    alb.ingress.kubernetes.io/target-type: instance
    alb.ingress.kubernetes.io/healthcheck-path: '/'
spec:
  ingressClassName: alb
  rules:
  - host: myapp.internal.example
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### 8.3) Variante B — `instance` + `externalTrafficPolicy: Local` (preserva client IP)
Service:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service-local
spec:
  type: NodePort
  externalTrafficPolicy: Local
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```
- Ingress: analogo all’esempio precedente (target-type: instance). Il controller registrerà solo i nodi con endpoints locali.

### 8.4) Variante C — `ip` (target diretto su IP pod)
Service:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service-ip
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```
Ingress:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress-ip
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
    alb.ingress.kubernetes.io/healthcheck-path: '/'
spec:
  ingressClassName: alb
  rules:
  - host: myapp.internal.example
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service-ip
            port:
              number: 80
```
> Nota: con `target-type: ip` il controller legge gli `EndpointSlices`/`Endpoints` e registra i pod IP nel TG.

---

## 9) Installazione e prerequisiti (generico)

### Prerequisiti generali
- AWS account con permessi per creare ALB, TargetGroup, Listeners, SecurityGroups, IAM roles, ENI.
- Cluster Kubernetes/EKS/ROSA/OpenShift funzionante.
- Accesso `kubectl` / `oc` al cluster.
- Permessi/ruoli IAM per il controller (IRSA su EKS è raccomandato).

### Installazione (high-level)
- **EKS**: installa AWS Load Balancer Controller (CRDs + Helm chart). Configura IRSA (ServiceAccount con ruolo IAM) e i permessi necessari.
- **OpenShift/ROSA**: installa l’**AWS Load Balancer Operator** da OperatorHub (gestisce installazione e RBAC). Fornisci i permessi IAM richiesti al controller/operatore.
- Dopo installazione:
  - verifica i pod del controller/operator (namespace `kube-system` o `openshift-operators` a seconda della distro).
  - assicurati che il ServiceAccount usato dal controller abbia il ruolo IAM con le policy necessarie.

Risorse ufficiali: controlla la documentazione AWS per la versione del controller e le istruzioni step-by-step (installazione Helm / OperatorHub / IRSA).

---

## 10) Comandi utili per debug

### Kubernetes / OpenShift
```bash
# Ingress
kubectl get ingress -A -o wide
kubectl describe ingress myapp-ingress -n myns

# Services
kubectl get svc -n myns
kubectl describe svc myapp-service -n myns

# Endpoints / EndpointSlices
kubectl get endpoints -n myns
kubectl describe endpoints myapp-service -n myns

kubectl get endpointslices -n myns
kubectl describe endpointslices -n myns -l kubernetes.io/service-name=myapp-service

# Pods / nodes
kubectl get pods -o wide -n myns
kubectl get nodes -o wide

# Controller logs
kubectl -n kube-system logs deploy/aws-load-balancer-controller
# OpenShift (operator)
oc -n openshift-operators logs deploy/<alb-operator-deploy>
```

### AWS CLI (ELBv2)
```bash
# list load balancers
aws elbv2 describe-load-balancers --region <region>

# describe specific load balancer
aws elbv2 describe-load-balancers --names <alb-name>
aws elbv2 describe-load-balancers --load-balancer-arns <arn>

# target groups
aws elbv2 describe-target-groups --region <region>

# target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# listeners and rules
aws elbv2 describe-listeners --load-balancer-arn <arn>
aws elbv2 describe-rules --listener-arn <listener-arn>
```

---

## 11) Health checks, access logs e metriche

- **Health checks**: il Target Group effettua health checks HTTP/HTTPS verso i target. Personalizza path/porta/protocol e threshold/timeout tramite annotazioni (o tramite configuration del controller).
- **Access logs**: ALB può salvare access logs su S3; abilita via console o con opzioni del controller/operator.
- **Metriche**: CloudWatch fornisce metriche ALB (RequestCount, TargetResponseTime, HealthyHostCount, UnHealthyHostCount, HTTPCode_Target_5XX_Count, ecc.). Configura allarmi CloudWatch per errori/latency/host unhealthy.
- **Controller metrics/logs**: il controller espone metriche Prometheus (se configurato) e log per debug.

---

## 12) Troubleshooting comune

### ALB non creato o non active
- Verifica permessi IAM del controller/operator.
- Controlla se subnets indicate esistono e sono corrette.
- Verifica security groups: ALB deve poter ricevere traffico sulle porte listener.
- Controlla i log del controller per errori AWS API.

### Health checks failing
- Controlla `healthcheck-path` e che l’app risponda.
- Verifica security group dei nodi/pod: permettere traffico dagli IP/SG dell’ALB.
- Controlla CloudWatch e `describe-target-health` per dettagli.

### ALB non aggiorna i target quando i pod cambiano
- Controlla che `EndpointSlices`/`Endpoints` vengano aggiornati.
- Controlla `target-type` atteso (instance vs ip) e comportamenti corrispondenti.
- Vedi i log del controller per eventuali errori di registrazione/deregistrazione.

### Client source IP non preservato
- Usa `externalTrafficPolicy: Local` per preservare l’IP sorgente.
- Oppure usa target-type `ip` e meccanismi di proxy se necessario.

### 503/502 o timeout
- Verifica che i target siano Healthy (TargetHealth)
- Verifica che NodePort e targetPort siano corretti.
- Controlla readiness probes dei pod: se non pronti il controller potrebbe registrarli comunque in base alla configurazione.

---

## 13) Best practices e limiti

- **Scegli target-type in base al bisogno**:
  - `instance + Cluster` per semplicità e resilienza.
  - `Local` se serve l’IP sorgente client.
  - `ip` per targeting diretto ma valuta limiti AWS e networking.
- **EndpointSlices**: abilitare/usarli per cluster grandi (migliori performance rispetto agli Endpoints).
- **Probes**: readiness/liveness probe corrette per non inviare traffico a pod non pronti.
- **Healthchecks**: mantenere healthcheck TG coerenti con readiness probe.
- **Security Groups**: configurare SG per permettere ALB→nodes/pods. Spesso si crea SG per ALB e si permette ingresso verso i nodi/port necessari.
- **IAM least privilege** per il controller (policy minime necessarie).
- **Logging & Monitoring**: abilitare access logs S3, CloudWatch metrics/alarms.
- **Limiti AWS**: controlla limiti su numero targets per TG, ENI per nodo (soprattutto per `ip` mode con VPC CNI), ecc.

---

## 14) Checklist rapida per deploy in un cluster vuoto

1. Verifica requisiti AWS (VPC, subnets, permessi IAM).
2. Installa AWS Load Balancer Controller / Operator (helm o OperatorHub).
3. Configura ServiceAccount con ruolo IAM (IRSA su EKS) se necessario.
4. Deploy dell’app (Deployment).
5. Service: NodePort per `instance`, ClusterIP per `ip` mode.
6. Crea Ingress con `ingressClassName: alb` e annotazioni (scheme, target-type, healthcheck, subnets/sg se serve).
7. Verifica che controller crei ALB su AWS (`aws elbv2 describe-load-balancers`).
8. Verifica Target Group e Target Health.
9. Abilita access logs e configura CloudWatch/alarms.
10. Test end-to-end (curl al DNS del ALB o con host configurato su DNS interno).

---

## 15) Appendice: comandi e snippet utili

### Verificare target health via AWS CLI
```bash
TG_ARN=$(aws elbv2 describe-target-groups --names <tg-name> --query 'TargetGroups[0].TargetGroupArn' --output text --region <region>)
aws elbv2 describe-target-health --target-group-arn $TG_ARN --region <region>
```

### Verificare ingress annotations
```bash
kubectl get ingress myapp-ingress -o yaml
```

### Estrarre EndpointSlices per un service
```bash
kubectl get endpointslices -n myns -l kubernetes.io/service-name=myapp-service -o yaml
```

### Logs controller
```bash
kubectl -n kube-system logs deploy/aws-load-balancer-controller
```

---

## Conclusione

Questa guida ti fornisce una visione completa e pratiche pronte all'uso per lavorare con ALB e Kubernetes/OpenShift. Contiene le varianti principali (`instance` vs `ip`, `Cluster` vs `Local`), manifest YAML pronti da adattare, comandi di debug e troubleshooting, e una checklist per partire da zero.

Se vuoi, posso:
- esportare questo documento come file `.md` e fornirti il download,
- generare una cartella con i manifest YAML separati e un `README` in un archivio zip scaricabile,
- o generare script di automazione (Helm chart o kustomize) per deployare tutto.

Dimmi quale opzione preferisci e lo preparo.

