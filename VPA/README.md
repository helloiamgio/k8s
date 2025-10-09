# Kubernetes Vertical Pod Autoscaler (VPA) — Guida approfondita

Questa guida spiega cosa è il **Vertical Pod Autoscaler (VPA)** in Kubernetes, come funziona, quando usarlo, le sue modalità operative e le best practice.  
Si basa sull’articolo “Kubernetes Vertical Pod Autoscaler” di PerfectScale e sulla documentazione ufficiale.

---

## Indice

1. Introduzione  
2. Che cos’è il VPA  
3. Modalità operative del VPA  
   - `Auto`  
   - `Recreate`  
   - `Off`  
4. Come funziona internamente  
5. Casi d’uso, vantaggi e limiti  
6. Esempi YAML  
7. Best practice consigliate  
8. Interazioni con HPA e Cluster Autoscaler  
9. Monitoraggio e considerazioni  
10. Riferimenti

---

## 1. Introduzione

Il **Vertical Pod Autoscaler** consente di **aggiustare dinamicamente le risorse** (CPU, memoria) richieste da un pod in base ai pattern di utilizzo. Invece di gestire il numero di repliche, VPA regola le risorse interne del pod.

---

## 2. Che cos’è il VPA

Il VPA osserva le metriche di utilizzo reale dei pod e calcola le risorse ottimali. Suggerisce o applica aggiornamenti alle richieste (requests) dei container, riducendo sprechi e migliorando la stabilità.

---

## 3. Modalità operative del VPA

- **Auto**: modifica automaticamente le risorse del pod.
- **Recreate**: ricrea i pod con le nuove risorse.
- **Off**: fornisce solo raccomandazioni.

---

## 4. Come funziona internamente

1. Osserva le metriche di utilizzo reale.  
2. Calcola richieste ottimali basate su modelli storici.  
3. Applica modifiche (se abilitato) o mostra raccomandazioni.  

![Schema VPA](https://www.perfectscale.io/hs-fs/hubfs/vpa-diagram.png)

---

## 5. Casi d’uso, vantaggi e limiti

**Vantaggi:**  
- Risorse più accurate  
- Riduzione sprechi  
- Stabilità migliorata  

**Limiti:**  
- Non adatto a pod stateful  
- Può causare restart frequenti  

---

## 6. Esempi YAML

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: "200m"
        memory: "256Mi"
      maxAllowed:
        cpu: "2"
        memory: "4Gi"
```

---

## 7. Best practice consigliate

- Imposta limiti minimi e massimi.  
- Evita modalità Auto su workload sensibili.  
- Monitora l’impatto sulle performance.  

---

## 8. Interazioni con HPA e Cluster Autoscaler

Il VPA può coesistere con l’HPA, ma agiscono su dimensioni diverse:  
- **VPA:** regola le risorse del pod.  
- **HPA:** regola il numero di pod.  

---

## 9. Monitoraggio e considerazioni

Verifica gli eventi VPA con `kubectl describe vpa <name>` e osserva suggerimenti tramite metriche Prometheus.

---

## 10. Riferimenti

- [PerfectScale - Kubernetes Vertical Pod Autoscaler](https://www.perfectscale.io/blog/kubernetes-vertical-pod-autoscaler)
- [Documentazione ufficiale Kubernetes - VPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
