# Kubernetes Horizontal Pod Autoscaler (HPA) — Guida completa

Guida completa all’**Horizontal Pod Autoscaler (HPA)** in Kubernetes: funzionamento, configurazione, metriche supportate, limiti e best practice.  
Basato sull’articolo “Kubernetes Horizontal Pod Autoscaler (HPA)” di PerfectScale.

---

## 1. Introduzione

L’**HPA** regola automaticamente il numero di repliche (pod) di un deployment in base a metriche come CPU o metriche personalizzate.

![HPA schema](https://www.perfectscale.io/hs-fs/hubfs/hpa-diagram.png)

---

## 2. Metriche supportate

- CPU e memoria tramite **Metrics Server**
- Metriche **personalizzate** definite dall’utente
- Metriche **esterne** (es. lunghezza di una coda)

---

## 3. Come funziona

1. L’HPA legge le metriche correnti.  
2. Confronta con i target definiti.  
3. Aggiorna automaticamente il numero di pod.

---

## 4. Esempio YAML

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
```

---

## 5. Best practice

- Imposta `minReplicas` > 1 per evitare downtime.  
- Usa metriche stabili e prive di picchi momentanei.  
- Evita conflitti con VPA su pod identici.  
- Monitora comportamento di scaling per evitare oscillazioni.

---

## 6. HPA + VPA + Cluster Autoscaler

- **HPA** scala orizzontalmente (repliche).  
- **VPA** scala verticalmente (risorse).  
- **Cluster Autoscaler** aggiunge o rimuove nodi.  

![Autoscaling interaction](https://www.perfectscale.io/hs-fs/hubfs/k8s-autoscaling-overview.png)

---

## 7. Monitoraggio e debugging

Verifica lo stato con:
```bash
kubectl get hpa
kubectl describe hpa my-app-hpa
```
Osserva metriche in Prometheus / Grafana per analizzare la risposta allo scaling.

---

## 8. Riferimenti

- [PerfectScale - Kubernetes Horizontal Pod Autoscaler (HPA)](https://www.perfectscale.io/blog/kubernetes-horizontal-pod-autoscaler-hpa)
- [Documentazione ufficiale Kubernetes - HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
