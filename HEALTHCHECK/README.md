# Health Check (Probe) in Kubernetes — Guida approfondita

Questa guida descrive in dettaglio come funzionano i *health check* (probe) in Kubernetes: i vari tipi (liveness, readiness, startup), i formati, i parametri, le interazioni e le best practice.  
Si basa sull’articolo *Kubernetes Health Check* di PerfectScale  e sulla documentazione ufficiale delle probe in Kubernetes.

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

Le *probe* in Kubernetes sono meccanismi per verificare lo stato dei container in modo che il sistema (kubelet / controller) sappia quando un container non è più sano o non è pronto per servire traffico.  
Senza probe, Kubernetes non distingue tra un processo “in esecuzione ma non funzionante” e uno che realmente serve. Le probe aiutano a migliorare la stabilità e l’affidabilità dell’applicazione.

---

## 2. Perché usare le probe

- Permettono di **riavviare** automaticamente container che si “bloccano” (deadlock, problemi interni) tramite la *livenessProbe*.  
- Evitano che un container “non pronto” riceva traffico prima che sia completamente inizializzato, tramite la *readinessProbe*.  
- Gestiscono scenari in cui un’app ha un avvio lento: la *startupProbe* può concedere un tempo maggiore prima di considerare il container non sano.  
- Aiutano a evitare interruzioni indesiderate e garantire che i pod servano traffico solo quando veramente pronti.

---

## 3. Tipi di probe

### livenessProbe

Verifica che il container sia “vivo” (non bloccato). Se fallisce consecutivamente, Kubernetes considera il container malfunzionante e lo riavvia.

### readinessProbe

Verifica che il container sia pronto per servire traffico. Se fallisce, il pod viene tolto dagli endpoint del Service, ma **non** viene riavviato.

### startupProbe

Serve per applicazioni con tempi di avvio lunghi (cold start). Finché la startupProbe non “passa”, le altre probe (liveness/readiness) sono sospese o ignorate per evitare riavvii prematuri.

---

## 4. Formati di probe

Le probe possono essere configurate in diversi modi:

### HTTP

Effettua una richiesta HTTP GET verso un endpoint del container:

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
