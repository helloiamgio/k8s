# Gateway API Course + Mini Lab su kind

Corso pratico in italiano per capire **API Gateway**, **Gateway API**, differenze rispetto a **Ingress NGINX** e **Istio**, con **mini lab completo su kind** pronto da usare e importabile in GitHub.

---

## Obiettivi del corso

Alla fine di questo mini-corso dovresti avere chiaro:

- che differenza c'è tra **API gateway** e **Gateway API**;
- perché **Gateway API** è considerata l'evoluzione di **Ingress**;
- come si collocano **NGINX** e **Istio** in questo modello;
- come pubblicare servizi HTTP con `Gateway` e `HTTPRoute`;
- come fare un piccolo test locale su **kind** con **NGINX Gateway Fabric**.

---

## 1. Prima distinzione fondamentale: API gateway vs Gateway API

Molto spesso i due termini vengono confusi, ma indicano cose diverse.

### API gateway

Un **API gateway** è un componente architetturale o un prodotto che espone API e centralizza alcune funzioni tipiche, per esempio:

- TLS termination
- autenticazione / autorizzazione
- routing verso backend
- rate limiting
- traffic shaping
- osservabilità lato edge
- trasformazioni di header o path

In pratica è la **porta di ingresso controllata** per chiamate HTTP/HTTPS verso servizi o microservizi.

### Gateway API

**Gateway API** invece è un insieme di **risorse Kubernetes standard** che descrivono come pubblicare e instradare il traffico.

Quindi:

- **API gateway** = il motore / il prodotto / il ruolo architetturale
- **Gateway API** = il linguaggio standard Kubernetes con cui descrivi il routing

Un prodotto può essere programmato tramite Gateway API.

---

## 2. Perché Gateway API è importante

L'API Kubernetes storica per pubblicare applicazioni HTTP è stata **Ingress**.

Ingress ha funzionato molto bene per gli scenari base, ma nel tempo ha mostrato alcuni limiti:

- modello abbastanza semplice e poco espressivo;
- molte funzioni avanzate demandate a **annotation proprietarie** dei vari controller;
- scarsa portabilità tra implementazioni diverse;
- governance meno chiara tra team piattaforma e team applicativi.

Gateway API nasce proprio per superare questi limiti.

### Idee chiave

Gateway API:

- separa meglio i ruoli;
- è più estensibile;
- è più leggibile;
- è più adatta a scenari enterprise e multi-team;
- riduce la dipendenza da annotation specifiche del singolo controller.

---

## 3. Le risorse principali di Gateway API

Le risorse fondamentali da conoscere sono queste.

### GatewayClass

Indica **quale implementazione/controller** gestirà i Gateway.

È simile all'idea di una `StorageClass`, ma per il traffico di rete.

Esempio mentale:

- `nginx` → implementazione NGINX
- `istio` → implementazione Istio
- controller cloud managed → implementazione del provider

### Gateway

Rappresenta il **punto di ingresso** reale nel cluster.

Qui definisci per esempio:

- porta
- protocollo
- hostname
- listener
- quali route possono collegarsi

Il `Gateway` è l'entrypoint.

### HTTPRoute

Definisce **come matchare il traffico HTTP** e **dove inviarlo**.

Per esempio:

- host `api.example.com`
- path `/orders`
- invio verso `orders-service:80`

L'`HTTPRoute` è la logica di routing.

### ReferenceGrant

Serve per autorizzare alcuni riferimenti cross-namespace.

È una misura di sicurezza e di governance.

---

## 4. Ingress vs Gateway API

### Con Ingress

Di solito mettevi in un singolo oggetto:

- hostname
- path
- backend
- TLS
- annotation custom del controller

### Con Gateway API

Il modello è separato:

- `GatewayClass` → chi implementa
- `Gateway` → dove entra il traffico
- `HTTPRoute` → come viene instradato

Questo rende il tutto molto più pulito.

### Vantaggio operativo

Il team piattaforma può gestire il `Gateway` condiviso.

I team applicativi possono gestire le `HTTPRoute` delle proprie app.

Questo è molto comodo in ambienti enterprise e multi-team.

---

## 5. NGINX in questo nuovo modello

Qui bisogna distinguere due cose.

### NGINX Ingress Controller

È il modello classico:

- usi oggetti `Ingress`
- il controller li traduce in config NGINX

### NGINX Gateway Fabric

È l'implementazione di **Gateway API** basata su NGINX.

Quindi:

- prima: `Ingress` + NGINX Ingress Controller
- ora/futuro: `Gateway API` + NGINX Gateway Fabric

### Modello mentale utile

Se vieni da NGINX:

- `Gateway` ≈ listener / blocco server
- `HTTPRoute` ≈ location + decisione di routing
- `GatewayClass` ≈ il controller che genera la config vera

Non è una equivalenza perfetta 1:1, ma aiuta molto.

---

## 6. Istio in questo modello

Istio non sparisce affatto.

Istio resta:

- una service mesh completa;
- un sistema avanzato per traffic management;
- un motore forte per mTLS, policy, osservabilità, resilienza.

La differenza è che sempre di più **Gateway API** diventa il linguaggio standard con cui descrivere il traffico, mentre **Istio** è una delle implementazioni possibili.

### In pratica

Se già conosci Istio:

- storicamente usavi `Gateway`, `VirtualService`, `DestinationRule`;
- sempre più spesso potrai descrivere i flussi usando `Gateway API`.

Istio supporta Gateway API e la direzione è quella di usarla sempre di più.

---

## 7. Quando parlare di “API gateway” in senso architetturale

Si parla di API gateway quando vuoi una facciata unica e governata per esporre API.

Esempi tipici:

- esporre microservizi verso l'esterno;
- centralizzare autenticazione;
- applicare rate limiting;
- controllare header e path;
- fare canary release;
- avere osservabilità lato edge.

### Attenzione

Gateway API da sola **non è automaticamente un prodotto full API management**.

Se ti servono funzioni come:

- developer portal
- subscription
- monetization
- analytics avanzate business
- piano/quote consumer

allora spesso serve un prodotto dedicato di API Management, o comunque una piattaforma più ricca del solo layer di routing.

---

## 8. Esempi pratici semplici

### Esempio 1 — Edge web classico

Vuoi pubblicare:

- `app.example.com/ui` → `frontend-svc`
- `app.example.com/api` → `api-svc`

Questo è il classico caso da `Gateway` + `HTTPRoute`.

### Esempio 2 — Canary

Vuoi mandare:

- 90% del traffico a `api-v1`
- 10% a `api-v2`

Gateway API lo supporta tramite `backendRefs` con `weight`.

### Esempio 3 — Shared ingress tra team

Il platform team crea un `Gateway` condiviso.

I team applicativi agganciano le loro `HTTPRoute`.

### Esempio 4 — Mesh / east-west

Nel mondo mesh, Gateway API può descrivere anche scenari di traffico interno tra servizi, non solo north-south.

---

## 9. Le 5 frasi da ricordare

1. **Ingress non è un API gateway**: è l'API Kubernetes storica per l'ingresso HTTP/HTTPS.
2. **Gateway API è l'evoluzione naturale di Ingress**.
3. **NGINX e Istio non spariscono**: sono o possono essere implementazioni di Gateway API.
4. **Gateway API separa entrypoint e routing**, quindi è più ordinata da governare.
5. **Le feature di API management completo dipendono dal prodotto**, non solo dalla spec standard.

---

## 10. Mini lab su kind

Questo lab usa:

- **kind** per creare un cluster Kubernetes locale;
- **NGINX Gateway Fabric** come implementazione Gateway API;
- due backend demo: `coffee` e `tea`.

### Flusso del lab

1. crei il cluster kind;
2. installi i CRD Gateway API;
3. installi NGINX Gateway Fabric;
4. crei due app demo;
5. definisci un `Gateway`;
6. definisci due `HTTPRoute`;
7. testi con `curl`.

---

## 11. Prerequisiti

Ti servono:

- Docker
- kind
- kubectl
- Helm
- curl

Verifica rapida:

```bash
kind version
kubectl version --client
helm version
docker version
```

---

## 12. Struttura del repo

```text
.
├── README.md
├── lab
│   ├── 01-kind-cluster.yaml
│   ├── 02-apps.yaml
│   ├── 03-gateway.yaml
│   └── 04-routes.yaml
├── examples
│   ├── 05-canary-example.yaml
│   └── 06-header-rewrite-example.yaml
└── scripts
    ├── bootstrap.sh
    └── cleanup.sh
```

---

## 13. Step 1 — Creazione cluster kind

File: `lab/01-kind-cluster.yaml`

Questo file crea un cluster kind con due port mapping:

- host `8080` → cluster listener HTTP
- host `8443` → cluster listener HTTPS

Creazione cluster:

```bash
kind create cluster --config lab/01-kind-cluster.yaml
kubectl cluster-info --context kind-kind
```

---

## 14. Step 2 — Installazione CRD Gateway API

Esegui:

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.4.2" | kubectl apply -f -
```

Verifica:

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

Dovresti vedere CRD come:

- `gatewayclasses.gateway.networking.k8s.io`
- `gateways.gateway.networking.k8s.io`
- `httproutes.gateway.networking.k8s.io`

---

## 15. Step 3 — Installazione NGINX Gateway Fabric

Esegui:

```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --create-namespace -n nginx-gateway \
  --set nginx.service.type=NodePort \
  --set-json 'nginx.service.nodePorts=[{"port":31437,"listenerPort":80},{"port":30478,"listenerPort":8443}]'
```

Verifiche:

```bash
kubectl get pods -n nginx-gateway
kubectl get gatewayclass
```

Dovresti vedere una `GatewayClass` chiamata `nginx`.

---

## 16. Step 4 — Deploy delle app demo

File: `lab/02-apps.yaml`

Crea due deployment e due service:

- `coffee`
- `tea`

Applica:

```bash
kubectl apply -f lab/02-apps.yaml
kubectl get pods
kubectl get svc
```

---

## 17. Step 5 — Creazione del Gateway

File: `lab/03-gateway.yaml`

Questo oggetto crea un listener HTTP su porta 80 con hostname `*.example.com`.

Applica:

```bash
kubectl apply -f lab/03-gateway.yaml
kubectl get gateways
kubectl describe gateway gateway
```

Controlla nello `describe` condizioni come:

- `Accepted=True`
- `Programmed=True`

---

## 18. Step 6 — Creazione delle route

File: `lab/04-routes.yaml`

Definisce:

- `cafe.example.com/coffee` → service `coffee`
- `cafe.example.com/tea` → service `tea`

Applica:

```bash
kubectl apply -f lab/04-routes.yaml
kubectl get httproutes
kubectl describe httproute coffee
kubectl describe httproute tea
```

Controlla condizioni come:

- `Accepted=True`
- `ResolvedRefs=True`

---

## 19. Step 7 — Test finale

Esegui:

```bash
curl -H 'Host: cafe.example.com' http://127.0.0.1:8080/coffee
curl -H 'Host: cafe.example.com' http://127.0.0.1:8080/tea
curl -H 'Host: cafe.example.com' http://127.0.0.1:8080/unknown
```

### Cosa aspettarsi

- `/coffee` risponde dal backend `coffee`
- `/tea` risponde dal backend `tea`
- `/unknown` non ha match e quindi fallisce o risponde con comportamento di default del gateway

---

## 20. Cosa succede davvero nel flusso

Il path della richiesta è questo:

```text
Client -> host:8080 -> extraPortMappings di kind -> NodePort del gateway NGINX -> Gateway listener -> HTTPRoute -> Service -> Pod
```

Questo è molto utile per capire dov'è il problema se qualcosa non funziona.

---

## 21. Troubleshooting rapido

### Problema: `GatewayClass` non compare

Verifica:

```bash
kubectl get pods -n nginx-gateway
kubectl logs -n nginx-gateway deploy/ngf-nginx-gateway-fabric
```

### Problema: `Gateway` non è `Programmed=True`

Verifica:

```bash
kubectl describe gateway gateway
kubectl get events -A --sort-by=.lastTimestamp
```

### Problema: `HTTPRoute` non è `Accepted=True`

Verifica:

```bash
kubectl describe httproute coffee
kubectl describe httproute tea
```

Controlla:

- nome del `parentRefs`
- `sectionName`
- hostname
- backend service name/port

### Problema: `curl` non funziona

Verifica:

```bash
docker ps
kubectl get svc -n nginx-gateway
kubectl get pods -o wide
ss -lntp | egrep '8080|8443'
```

### Problema: backend non raggiungibile

Verifica:

```bash
kubectl get endpoints coffee tea
kubectl describe svc coffee
kubectl describe svc tea
kubectl logs deploy/coffee
kubectl logs deploy/tea
```

---

## 22. Estensione 1 — Canary 90/10

File: `examples/05-canary-example.yaml`

Questo esempio mostra come dividere il traffico tra due backend con pesi differenti.

Uso tipico:

- rollout graduale
- test di una nuova versione
- canary controllato

---

## 23. Estensione 2 — Header rewrite

File: `examples/06-header-rewrite-example.yaml`

Questo esempio mostra come aggiungere un header alla request con un filtro `RequestHeaderModifier`.

Uso tipico:

- debug
- tracing
- policy semplificate
- aggiunta di metadati applicativi

---

## 24. Bootstrap rapido del lab

Puoi usare lo script `scripts/bootstrap.sh` per:

- creare il cluster kind;
- installare i CRD Gateway API;
- installare NGINX Gateway Fabric;
- applicare le app demo;
- applicare Gateway e Routes.

Esecuzione:

```bash
chmod +x scripts/bootstrap.sh scripts/cleanup.sh
./scripts/bootstrap.sh
```

Test finale:

```bash
curl -H 'Host: cafe.example.com' http://127.0.0.1:8080/coffee
curl -H 'Host: cafe.example.com' http://127.0.0.1:8080/tea
```

---

## 25. Cleanup

Per eliminare il cluster:

```bash
./scripts/cleanup.sh
```

---

## 26. Come tradurre mentalmente da Ingress NGINX a Gateway API

### Prima

```text
Ingress + annotations NGINX + service backend
```

### Dopo

```text
GatewayClass + Gateway + HTTPRoute + eventuali policy/filter
```

### Regola semplice

- ciò che riguarda il **punto di ingresso** va nel `Gateway`
- ciò che riguarda il **match e il routing HTTP** va nella `HTTPRoute`
- ciò che riguarda l'**implementazione concreta** dipende dalla `GatewayClass`

---

## 27. Quando userei NGINX, quando Istio

### NGINX / NGINX Gateway Fabric

Buona scelta se vuoi:

- edge HTTP/HTTPS chiaro e semplice;
- un modello vicino al mondo NGINX;
- un ingresso Kubernetes standard senza introdurre tutta la complessità mesh.

### Istio

Buona scelta se vuoi anche:

- service mesh vera;
- mTLS diffuso;
- policy avanzate east-west;
- resilienza e osservabilità molto spinte.

---

## 28. In sintesi finale

La frase più utile da portarsi a casa è questa:

> Gateway API è il nuovo standard Kubernetes per descrivere il traffico ingress e, sempre di più, anche scenari mesh; NGINX e Istio sono implementazioni o motori che possono usare questo standard.

---

## 29. Fonti ufficiali consigliate

### Kubernetes

- Gateway API concepts: https://kubernetes.io/docs/concepts/services-networking/gateway/
- Gateway API overview: https://gateway-api.sigs.k8s.io/
- HTTPRoute: https://gateway-api.sigs.k8s.io/api-types/httproute/
- ReferenceGrant: https://gateway-api.sigs.k8s.io/api-types/referencegrant/
- Migrating from Ingress: https://gateway-api.sigs.k8s.io/guides/getting-started/migrating-from-ingress/

### NGINX Gateway Fabric

- Overview: https://docs.nginx.com/nginx-gateway-fabric/
- Get started on kind: https://docs.nginx.com/nginx-gateway-fabric/get-started/
- GitHub project: https://github.com/nginx/nginx-gateway-fabric

### Istio

- Gateway API support in Istio: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/

### kind

- kind documentation: https://kind.sigs.k8s.io/
- kind quick start: https://kind.sigs.k8s.io/docs/user/quick-start/

---

## 30. Comandi rapidi utili

```bash
kubectl get gatewayclass
kubectl get gateways
kubectl get httproutes
kubectl describe gateway gateway
kubectl describe httproute coffee
kubectl describe httproute tea
kubectl get events -A --sort-by=.lastTimestamp
kubectl logs -n nginx-gateway deploy/ngf-nginx-gateway-fabric
```

---

## 31. Nota finale pratica

Questo repo è pensato come base didattica e di laboratorio.

Per ambienti reali valuta sempre:

- TLS vero con certificati gestiti;
- DNS reale;
- osservabilità;
- sicurezza e policy;
- feature supportate dalla specifica implementazione usata;
- eventuali prodotti API management se servono capabilities più avanzate.

