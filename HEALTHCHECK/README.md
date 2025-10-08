# Health Check (Probe) in Kubernetes 

Questa guida descrive in dettaglio come funzionano i *health check* (probe) in Kubernetes: i vari tipi (liveness, readiness, startup), i formati, i parametri, le interazioni e le best practice.
Si basa sull’articolo *Kubernetes Health Check* di PerfectScale e sulla documentazione ufficiale delle probe in Kubernetes.

---

## Indice

1. Introduzione  
2. Perché usare le probe  
3. Tipi di probe  
   - livenessProbe  
   - readinessProbe  
   - startupProbe  
4. Formati di probe  
   - HTTP  
   - TCP  
   - Exec / Command  
   - gRPC (via exec)  
5. Parametri delle probe  
6. Flusso temporale, interazioni e comportamento  
7. Esempi concreti e casi d’uso  
8. Best practice da PerfectScale (e caveat)  
9. Riferimenti

---

## 1. Introduzione

Le *probe* in Kubernetes sono meccanismi per verificare lo stato dei container in modo che il sistema sappia quando un container non è più sano o non è pronto per servire traffico.

---

## 2. Perché usare le probe

- Riavviare automaticamente container bloccati tramite la *livenessProbe*  
- Evitare che container non pronti ricevano traffico tramite la *readinessProbe*  
- Gestire applicazioni con avvio lento tramite la *startupProbe*  
- Migliorare stabilità e affidabilità

---

## 3. Tipi di probe

### livenessProbe
Verifica che il container sia “vivo”. Se fallisce consecutivamente, Kubernetes riavvia il container.

### readinessProbe
Verifica che il container sia pronto per servire traffico. Se fallisce, il pod viene tolto dagli endpoint del Service ma non riavviato.

### startupProbe
Per applicazioni con avvio lento. Finché la startupProbe non passa, le altre probe sono sospese per evitare riavvii prematuri.

---

## 4. Formati di probe

### HTTP
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

### TCP
```yaml
readinessProbe:
  tcpSocket:
    port: 3306
  timeoutSeconds: 5
```

### Exec / Command
```yaml
livenessProbe:
  exec:
    command:
      - cat
      - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 10
```

### gRPC (via exec)
Usare `exec` con tool tipo `grpc-health-probe`.

---

## 5. Parametri delle probe

| Parametro | Descrizione |
|---|---|
| initialDelaySeconds | Attesa all’avvio prima della prima prova |
| periodSeconds | Intervallo tra esecuzioni successive |
| timeoutSeconds | Tempo massimo per attendere risposta |
| failureThreshold | Numero massimo di fallimenti consecutivi prima dell’azione |
| successThreshold | Numero minimo di successi consecutivi per considerare la probe passata |

---

## 6. Flusso temporale, interazioni e comportamento

![Flusso health check](https://tse4.mm.bing.net/th/id/OIP.r9mhAU0JRPEypOUq2O7gowHaGA?pid=Api)

- Il container parte  
- Dopo `initialDelaySeconds` viene eseguita la startupProbe (se presente)  
- Se startupProbe passa, liveness e readiness entrano in funzione  
- Liveness fallita → container riavviato  
- Readiness fallita → pod rimosso dagli endpoint del service  
- Readiness successiva → pod reinserito nel servizio

![Diagramma decisionale probe](https://tse4.mm.bing.net/th/id/OIP.LdVTa7CSUpJWCLhohM8brQHaJD?pid=Api)

---

## 7. Esempi concreti e casi d’uso

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: mia-app:latest
    ports:
    - containerPort: 8080
    startupProbe:
      httpGet:
        path: /healthz
        port: 8080
      failureThreshold: 30
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 10
      timeoutSeconds: 2
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 1
      failureThreshold: 3
      successThreshold: 1
```

Casi d’uso: database (Redis) → TCP probe insufficiente; applicazioni slow-start → usare startupProbe.

---

## 8. Best practice e caveat

- Non usare TCP per HTTP senza controlli supplementari  
- Endpoint di health dovrebbero controllare dipendenze  
- Probe leggere, non eseguire operazioni pesanti  
- Usare startupProbe per container con avvio lento  
- Monitorare log ed eventi dei pod per debug

---

## 9. Riferimenti

- PerfectScale: [Kubernetes Health Check](https://www.perfectscale.io/blog/kubernetes-health-check)  
- Kubernetes docs: [Configure liveness, readiness, startup probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

---

*Fine del file*.
