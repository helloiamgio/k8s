# Scheduling in Kubernetes: funzionamento avanzato

Questa guida descrive in dettaglio come funziona lo scheduling in Kubernetes, con particolare attenzione al meccanismo di **scoring / ranking**. Si basa sull’articolo *Kubernetes Scheduling: How It Works and Key Factors* di PerfectScale e sulla documentazione ufficiale del framework di scheduling di Kubernetes. :contentReference[oaicite:1]{index=1}

---

## Indice

1. Panoramica  
2. Flusso generale dello scheduling  
3. Fase di filtraggio (Filter)  
4. Fase di punteggio / ranking (Score / Normalize / Combine)  
   - PreScore / Score plugins  
   - NormalizeScore  
   - Ponderazione (weights)  
5. Binding / Associazione  
6. Alcune estensioni e casi particolari  
   - PostFilter & Preemption  
   - StorageCapacityScoring  
   - Plugin custom  
7. Meccanismi per influenzare lo scheduling  
   - Affinità / anti-affinità, nodeAffinity  
   - Taints / Tolerations  
   - TopologySpreadConstraints  
8. Glossario  
9. Riferimenti  

---

## 1. Panoramica

Quando un Pod viene creato (ad esempio tramite `kubectl apply`), esso entra in stato `Pending` finché non viene schedulato su un nodo. Il **kube-scheduler** monitora continuamente i Pod senza nodo assegnato e cerca di “piazzarli” nei nodi più opportuni.  

Il processo si articola in diverse fasi: filtraggio, punteggio (scoring), normalizzazione, combinazione dei punteggi e binding.  

L’articolo di PerfectScale evidenzia che “the scheduler ranks each compatible node and the one with the highest score is chosen for the Pod.” :contentReference[oaicite:2]{index=2}

Nella documentazione ufficiale, il framework è strutturato come plugin estensibili in vari punti (PreFilter, Filter, PreScore, Score, NormalizeScore, PostFilter). :contentReference[oaicite:3]{index=3}

---

## 2. Flusso generale dello scheduling

Ecco un diagramma semplificato del flusso:  

1. Il Pod viene creato → stato Pending  
2. Il scheduler lo intercetta  
3. **Filtering**: scarta nodi che non possono supportarlo  
4. **Scoring**: per ogni nodo rimanente calcola un punteggio  
5. **Normalize & Combine**: normalizza i punteggi e li combina secondo pesi dei plugin  
6. Seleziona il nodo con punteggio più alto  
7. **Binding**: associa il Pod al nodo scelto  
8. Il `kubelet` sul nodo assegnato avvia i container  

Nell’immagine: nodi filtrati, nodi con punteggi, nodo scelto.  
(Vedi figura sopra)  

---

## 3. Fase di filtraggio (Filter)

In questa fase il scheduler esegue una serie di controlli (plugin di tipo *Filter*) su ciascun nodo candidato, e scarta quelli che **non soddisfano requisiti “hard”** del Pod. Se un nodo fallisce anche un solo plugin Filter, non sarà più considerato nelle fasi successive. :contentReference[oaicite:4]{index=4}

Esempi di controlli:

- **PodFitsResources**: il nodo deve avere risorse libere sufficienti (CPU, memoria) :contentReference[oaicite:5]{index=5}  
- **NodeUnschedulable**: esclude nodi marcati come non schedulabili  
- **PodToleratesNodeTaints**: verifica che il Pod tolleri eventuali taint del nodo  
- **VolumeBinding / Storage**: controlli relativi ai volumi richiesti (zone, disponibilità)  
- **NodeSelector / NodeAffinity “required”**: se il Pod richiede etichette specifiche  
- Altri plugin relativi a limiti di volumi CSI, conflitti di disco, porta host, ecc. :contentReference[oaicite:6]{index=6}  

Se non resta nessun nodo factibile dopo il filtraggio, si può attivare la fase **PostFilter** (es. preemption) per provare a liberare nodi tramite rimozione di altri pod. :contentReference[oaicite:7]{index=7}

---

## 4. Fase di punteggio / ranking (Scoring / Normalize / Combine)

Questa è la parte che vuoi approfondire: come i nodi che “superano” il filtro vengono valutati e ordinati.

### 4.1 PreScore e Score Plugins

- **PreScore** plugin: esegue lavoro preliminare utile per il calcolo del punteggio (es. aggregare dati, preparare struttura dati condivisa). :contentReference[oaicite:8]{index=8}  
- **Score** plugin: per ogni nodo, calcola un punteggio intermedio basato su un criterio specifico. Ogni plugin Score restituisce un valore in un range definito (es. 0–100 o valori configurati). :contentReference[oaicite:9]{index=9}  

Esempi di plugin Score comuni:

- **NodeResourcesBalancedAllocation**: favorisce nodi con uso bilanciato di CPU vs memoria  
- **ImageLocality**: preferisce nodi che già hanno l’immagine richiesta in cache  
- **InterPodAffinity / AntiAffinity**: considera la vicinanza o la distanza a pod con etichette specifiche  
- **NodePreferAvoidPods**: penalizza nodi dove ci sono pod che l’utente preferirebbe evitare  
- **StorageCapacityScoring**: se abilitato, calcola un punteggio basato sulla capacità residua dei volumi (feature alpha in v1.33). :contentReference[oaicite:10]{index=10}  

### 4.2 NormalizeScore

Dopo che ogni Score plugin ha prodotto valori per i nodi, entra in gioco la fase di normalizzazione (**NormalizeScore**). Serve a trasformare i punteggi in un range comune e comparabile, garantendo che nessun plugin domini indebitamente il risultato solo per differenze di scala. :contentReference[oaicite:11]{index=11}

Ad esempio, se un plugin genera valori da 0 a 10 e un altro da 0 a 1000, la normalizzazione riporta tutto in un range uniforme (es. 0–100) prima della fase di somma ponderata.

### 4.3 Combinazione e pesi (weights)

Dopo la normalizzazione, il scheduler combina i punteggi dei vari plugin, moltiplicandoli per pesi configurati (weight) e sommando i risultati per ottenere un **punteggio totale** per ciascun nodo. :contentReference[oaicite:12]{index=12}  

Formula semplificata:

