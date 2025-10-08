# Health Check in Kubernetes — guida approfondita

Questa guida descrive come funzionano i health check (probe) in Kubernetes, esplorando i vari tipi (liveness, readiness, startup) e come usarli nei manifesti dei Pod. Si basa sull’articolo *Kubernetes Health Check* di PerfectScale e sulla documentazione ufficiale di Kubernetes.

---

## Indice

1. Introduzione  
2. Perché servono gli health check  
3. Tipi di probe  
   - **livenessProbe**  
   - **readinessProbe**  
   - **startupProbe**  
4. Formati di probe  
   - HTTP  
   - TCP  
   - Command (exec)  
5. Parametri principali  
   - initialDelaySeconds  
   - periodSeconds  
   - timeoutSeconds  
   - successThreshold  
   - failureThreshold  
6. Interazione tra le probe  
7. Esempi in manifesti  
8. Best practice e consigli  
9. Riferimenti  

---

## 1. Introduzione

I health check (probe) servono a far sì che Kubernetes possa capire se un container è “vivo” oppure “pronto” per servire traffico. Consentono al kubelet/scheduler di reagire a condizioni in cui un container non funziona correttamente, ad esempio riavviandolo o escludendolo dal servizio.

---

## 2. Perché servono gli health check

Senza probe:

- Potresti avere container che sono in esecuzione (il processo non è terminato), ma non rispondono correttamente.  
- Kubernetes non saprebbe distinguere tra “funziona ma lento/non risponde” e “è morto”.  
- La disponibilità e resilienza delle applicazioni sarebbero peggiori.

Con le probe, Kubernetes può:

- Riavviare i container che falliscono la liveness probe  
- Non inviare traffico a container che non passano la readiness probe  
- Evitare che un container appena avviato ingaggi traffico prematuramente (startup probe)

---

## 3. Tipi di probe

### livenessProbe

Indica se il container è “vivo”. Se fallisce, Kubernetes considera il container non funzionante e lo riavvia.  
È utile per gestire situazioni di deadlock, memoria corrotta o blocchi interni.

### readinessProbe

Indica se il container è “pronto” per accettare traffico. Se fallisce, Kubernetes esclude il pod dal set di endpoint del servizio, ma non lo riavvia.  
Serve per gestire fasi di warm-up, caricamenti iniziali, dipendenze esterne iniziali.

### startupProbe (versione più recente)

Serve per applicazioni che hanno tempi lunghi di inizializzazione (es. avvio lento). Kubernetes può usare la startupProbe inizialmente per permettere un tempo extra prima che le altre probe falliscano e causino riavvii prematuri.

---

## 4. Formati di probe

Le probe possono essere configurate in tre modalità:

1. **HTTP**  
   ```yaml
   livenessProbe:
     httpGet:
       path: /healthz
       port: 8080
     initialDelaySeconds: 5
     periodSeconds: 10
