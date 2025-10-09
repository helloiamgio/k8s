# Kubernetes CPU Limit — Best Practices per Prestazioni Ottimali

Basato sull’articolo di PerfectScale *“Kubernetes CPU Limit: Best Practices for Optimal Performance”*, questa guida spiega come funzionano i **limiti e le richieste CPU** in Kubernetes, come influiscono sullo scheduling, e come configurarli correttamente per evitare colli di bottiglia o sprechi di risorse.

---

## Indice

1. Introduzione  
2. Differenza tra CPU Request e CPU Limit  
3. Come Kubernetes gestisce la CPU  
4. Problemi causati da limiti CPU troppo bassi o troppo alti  
5. Best Practices per i limiti CPU  
6. Esempi YAML e scenari pratici  
7. Monitoraggio e ottimizzazione continua  
8. Conclusioni  
9. Riferimenti

---

## 1. Introduzione

Le risorse CPU in Kubernetes vengono gestite tramite **request** e **limit**.  
Definire correttamente questi valori è fondamentale per garantire che i pod abbiano prestazioni costanti senza compromettere la stabilità del cluster.


Un’errata configurazione dei limiti CPU può portare a fenomeni come:

- **CPU throttling** (limitazione forzata della CPU da parte del kernel)
- **Underutilization** (uso inefficiente delle risorse)
- **Instabilità nei pod critici**

---

## 2. Differenza tra CPU Request e CPU Limit

| Tipo | Descrizione | Effetto |
|------|--------------|----------|
| **Request** | Quantità minima di CPU garantita al pod | Usata dallo scheduler per decidere dove posizionare il pod |
| **Limit** | Quantità massima di CPU che il pod può utilizzare | Imposta un limite rigido oltre il quale il container viene throttled |

> ⚙️ *Se un container supera il suo CPU limit, il kernel limita la frequenza della CPU, causando rallentamenti visibili nell’applicazione.*

---

## 3. Come Kubernetes gestisce la CPU

Kubernetes non “prenota” la CPU come la memoria, ma utilizza il **CPU share model** del kernel Linux.  
Quando il cluster ha carichi elevati, il tempo CPU viene diviso tra i pod in base ai loro **CPU shares**, determinati dalla `request`.


### Comportamento chiave

- Se **limit = request**, il container ha CPU fissa e predicibile.  
- Se **limit > request**, il container può “burstare” temporaneamente, ma può subire throttling.  
- Se **limit non è impostato**, il container può consumare tutta la CPU del nodo finché è disponibile.

---

## 4. Problemi causati da limiti CPU errati

### a. Limiti troppo bassi

- Il container viene throttled spesso, causando **latenze elevate**.  
- Performance degradate anche con risorse disponibili.

### b. Limiti troppo alti o assenti

- Il pod può monopolizzare la CPU del nodo, causando **starvation** ad altri pod.  
- Difficoltà di scheduling in ambienti condivisi.

### c. Differenza eccessiva tra `request` e `limit`

- Può causare sbilanciamento nel cluster e comportamenti imprevedibili sotto carico.

---

## 5. Best Practices per i limiti CPU

### 🔹 1. Evita di impostare limiti CPU rigidi per pod critici

Lascia che i pod critici possano utilizzare più CPU in caso di necessità, impostando solo `requests` senza `limits`.

### 🔹 2. Imposta richieste realistiche

Basati su dati reali raccolti da Prometheus o strumenti come PerfectScale.

```yaml
resources:
  requests:
    cpu: "250m"
  limits:
    cpu: "500m"
```

### 🔹 3. Non usare gli stessi valori per tutti i pod

Ogni workload ha comportamenti diversi — adatta i limiti in base al profilo di utilizzo.

### 🔹 4. Usa strumenti di autoscaling

Kubernetes HPA (Horizontal Pod Autoscaler) e VPA (Vertical Pod Autoscaler) aiutano a mantenere un equilibrio dinamico.

### 🔹 5. Monitora i throttling event

Usa metriche come:  
```promql
rate(container_cpu_cfs_throttled_seconds_total[5m])
```
per rilevare quando i container vengono limitati.

---

## 6. Esempi YAML e scenari pratici

### Esempio 1 — Pod con limiti troppo rigidi

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: throttled-pod
spec:
  containers:
  - name: throttled
    image: nginx
    resources:
      requests:
        cpu: "200m"
      limits:
        cpu: "200m"
```

> ❌ In questo caso, se l’applicazione necessita di più CPU, verrà immediatamente throttled.

### Esempio 2 — Configurazione bilanciata

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: balanced-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: myapp:v2
        resources:
          requests:
            cpu: "500m"
          limits:
            cpu: "1"
```

> ✅ Buon equilibrio tra garanzia e flessibilità.

---

## 7. Monitoraggio e ottimizzazione continua

Strumenti consigliati da PerfectScale:

- **Prometheus + Grafana** → per visualizzare CPU usage e throttling
- **Vertical Pod Autoscaler** → per suggerimenti automatici sulle risorse
- **PerfectScale** → analizza pattern di utilizzo e suggerisce limiti ottimali


---

## 8. Conclusioni

Un corretto bilanciamento tra *requests* e *limits* è essenziale per:

- Evitare sprechi di CPU  
- Prevenire throttling eccessivo  
- Ottimizzare i costi del cluster  
- Garantire prestazioni stabili e prevedibili

> 🎯 *“Gestire correttamente i limiti CPU è come regolare il motore di un’auto: troppo basso e non parte, troppo alto e si surriscalda.”*

---

## 9. Riferimenti

- PerfectScale Blog — [Kubernetes CPU Limit: Best Practices](https://www.perfectscale.io/blog/kubernetes-cpu-limit-best-practises)  
- Kubernetes Docs — [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

---

*Fine del file*.
