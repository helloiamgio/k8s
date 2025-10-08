# Scheduling in Kubernetes

Questa guida spiega come funziona il processo di *scheduling* in Kubernetes: come i **Pod** vengono assegnati ai **nodi** del cluster in base a fattori di compatibilità, priorità, risorse e regole di policy. Le spiegazioni sono in italiano e includono immagini esplicative.

---

## Indice

1. Panoramica  
2. Il processo di scheduling  
   - Fase di filtraggio (Filtering / Predicates)  
   - Fase di punteggio (Scoring / Priorities)  
   - Binding (Associazione Pod → Nodo)  
3. Meccanismi per influenzare lo scheduling  
   - nodeSelector  
   - nodeAffinity  
   - podAffinity / podAntiAffinity  
   - taints e tolerations  
   - topologySpreadConstraints  
4. Altri concetti avanzati  
   - Preemption  
   - QoS Classes  
   - Scheduler personalizzati  
   - Limitazioni e sfide  
5. Glossario  
6. Risorse aggiuntive  

---

## 1. Panoramica

Quando crei un workload (ad esempio un `Deployment`), il **kube‑apiserver** riceve la richiesta e la memorizza in **etcd**. Quindi il controller genera i Pod che nascono con status `Pending`, ovvero non assegnati a nessun nodo.  
È il **kube‑scheduler** che si occupa di decidere, per ogni Pod in stato `Pending`, su quale nodo debba essere eseguito.

![Flusso di scheduling in Kubernetes](https://tse3.mm.bing.net/th/id/OIP.H2LKePqGBcJz8LPuhM4YrgHaEK?pid=Api)

---

## 2. Il processo di scheduling

Il processo di scheduling si compone di tre macro‑fasi:

1. **Filtraggio (Filtering)**  
2. **Punteggio / Classifica (Scoring / Ranking)**  
3. **Binding (associazione effettiva del Pod al Nodo)**  

### a) Filtraggio (Filtering / Predicates)

![Fase di filtraggio dei nodi](https://tse4.mm.bing.net/th/id/OIP.LdVTa7CSUpJWCLhohM8brQHaJD?pid=Api)

In questa fase lo scheduler valuta tutti i nodi del cluster e scarta quelli che **non soddisfano** i requisiti minimi del Pod. Solo i nodi che “passano” il filtraggio sono considerati *feasible nodes*.

### b) Punteggio (Scoring / Priorities)

![Fase di scoring in Kubernetes](https://tse4.mm.bing.net/th/id/OIP.r9mhAU0JRPEypOUq2O7gowHaGA?pid=Api)

Tra i nodi compatibili, lo scheduler calcola un punteggio per ciascuno, in base a funzioni di priorità. L’obiettivo è scegliere non solo un nodo compatibile, ma il **migliore** secondo criteri di efficienza, bilanciamento del carico e altri vincoli.

### c) Binding

![Binding finale del Pod al nodo scelto](https://tse4.mm.bing.net/th/id/OIP.9nvkREG34GCLCGzy4ooknQHaHr?pid=Api)

Una volta scelto il nodo migliore, lo scheduler effettua il **binding**: associa il Pod al nodo aggiornando lo stato del Pod (attraverso l’API server / etcd). A questo punto il kubelet del nodo prescelto si accorge del nuovo Pod e procede a far partire i container.

---

## 3. Meccanismi per influenzare lo scheduling

### nodeSelector

```yaml
spec:
  nodeSelector:
    gpu: "true"
```

### nodeAffinity

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: zone
          operator: In
          values:
          - europe-west1
```

### podAntiAffinity

```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          app: web
      topologyKey: "kubernetes.io/hostname"
```

### Taints e Tolerations

```yaml
tolerations:
- key: "gpu-dedicated"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

### topologySpreadConstraints

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: "zone"
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: my-app
```

---

## 4. Altri concetti avanzati

### Preemption

Se lo scheduler non trova risorse libere per un pod ad alta priorità, può “preemptare” (ossia terminare) pod a priorità inferiore per liberare spazio.

### QoS Classes

- **Guaranteed**: `requests == limits`
- **Burstable**: `requests < limits`
- **BestEffort**: nessuna richiesta esplicita

### Scheduler personalizzati

Puoi creare scheduler custom oltre al default `kube-scheduler` e assegnare pod specifici tramite `schedulerName`.

---

## 5. Glossario

| Termine | Definizione |
|---|---|
| Pod | Unità atomica di deployment in Kubernetes |
| Nodo | Macchina fisica o virtuale che ospita i Pod |
| kubelet | Agente che gestisce i container sul nodo |
| kube-scheduler | Componente che decide su quale nodo schedulare i Pod |
| Taint / Toleration | Meccanismi per vincolare i pod su nodi specifici |
| Affinità / Anti-affinità | Regole di prossimità o separazione tra pod |
| QoS Classes | Classi di servizio in base a richieste e limiti |

---

## 6. Risorse aggiuntive

- Documentazione ufficiale Kubernetes: [https://kubernetes.io/docs/concepts/scheduling-eviction/](https://kubernetes.io/docs/concepts/scheduling-eviction/)
