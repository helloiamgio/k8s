# Scheduling in Kubernetes — spiegazione dettagliata (basata su PerfectScale)

Questa guida approfondita descrive il processo di scheduling in Kubernetes e, in particolare, lo **scoring / ranking** dei nodi. Il testo si basa sull'articolo *Kubernetes Scheduling: How It Works and Key Factors* di PerfectScale (link in fondo) e sulla documentazione ufficiale del framework di scheduling di Kubernetes. Le immagini sono prese dallo stesso articolo (hotlink alle immagini sul CDN di PerfectScale).

---

## Indice

1. Panoramica  
2. Flusso generale dello scheduling (diagramma)  
3. Filtraggio (Filtering / Predicates) — breve riepilogo + immagine  
4. Scoring / Ranking — spiegazione dettagliata e esempio numerico (con formula di normalizzazione)  
   - PreScore / Score plugins  
   - NormalizeScore: cosa fa e perché è importante  
   - Combinazione dei punteggi con pesi (weights)  
   - Esempio numerico passo-passo  
5. Binding e casi particolari (preemption, PostFilter)  
6. Come influenzare lo scheduling dal manifesto del Pod (nodeAffinity, taints, podAffinity, topologySpread)  
7. Riferimenti e immagini

---

## 1) Panoramica (breve)

Quando un Pod viene creato, il `kube-scheduler` valuta i nodi del cluster per assegnare il Pod al nodo "migliore". Il processo principale è in tre fasi: **filtraggio** (escludere nodi non idonei), **scoring** (assegnare un punteggio ai nodi rimasti) e **binding** (associare il pod al nodo con punteggio più alto). Le spiegazioni e diagrammi seguenti provengono dall'articolo di PerfectScale (vedi riferimenti).

---

## 2) Flusso generale dello scheduling (diagramma)

![Kubernetes Scheduling Process](https://cdn.prod.website-files.com/635e4ccf77408db6bd802ae6/67973c6ae9d04f194a8141b8_AD_4nXe-MnVx9bQ4I6ZXMEzEhl6yQrZj1KdFboR32_9E4Aa3xWqTtDTbgRx3P72LBkTQmag_otjB6q-pfW_7Cwd46NUYjPJVwitYO_AvytfUtXcvjXXSoPFApbcnesYoEKWMVKaXXJ9UcA.jpeg)

*Figura: flusso generale del processo di scheduling (Fonte: PerfectScale).*

---

## 3) Filtraggio (Filtering / Predicates)

![Filtering Phase](https://cdn.prod.website-files.com/635e4ccf77408db6bd802ae6/67973c6ab83dd57ac7dfc41f_AD_4nXer7VWzcpcsN6PaQbmRUIly_c4YTu2SPsUDpO3-w7uDsO533IsxSWAo05o7RAndcZKABXz4uSC8oMF89N9QMtec0qGQexe4UohmUeG7-tiJqrLQ20z40EyfuB0Rzfva82tPEO3OEQ.jpeg)

La fase di **filtering** applica controlli "hard" su ciascun nodo (es.: disponibilità risorse, taints/tolerations, capacità di mount del volume, nodeSelector/nodeAffinity richieste). I nodi che non passano almeno uno dei predicati vengono scartati e non considerati per lo scoring.

**Esempi di predicati comuni**:
- `PodFitsResources` (sufficiente CPU/memoria)  
- `NodeUnschedulable`  
- `VolumeBinding` / storage zone compatibility  
- `PodToleratesNodeTaints`  
(PerfectScale indica che ci sono 13 predicati di default nel processo di filtraggio.)

---

## 4) Scoring / Ranking — spiegazione approfondita

![Scoring Phase](https://cdn.prod.website-files.com/635e4ccf77408db6bd802ae6/67973c6aa7fa275459cde909_AD_4nXfCwGvbwj8_RfwIzpl46FXMmBeOxjkt3DlIJ_N2dC3RyWZajDK0aldyPrpgvEqwXFYyDdCeSqEsNrV9awExW8-hLriQ3gZJYUdi3OsgK9Rhdyvf5D0QCXDwNq1uwXyYWeW3IBroUA.jpeg)

Questa è la parte centrale della guida. Dopo il filtraggio lo scheduler usa *plugin* di tipo **Score** per **valutare ogni nodo compatibile**. Ogni plugin Score calcola un valore (raw score) per ciascun nodo in base a un criterio (image locality, bilanciamento risorse, affinità inter-pod, ecc.).

### 4.1 PreScore e Score
- **PreScore**: plugin opzionale che prepara dati condivisi utili per lo scoring (ad es. calcoli aggregati).  
- **Score**: plugin che, per ogni nodo, ritorna un punteggio (intero) che rappresenta quanto il nodo soddisfa quel criterio.

> Nota: idealmente i plugin Score producono valori nell'intervallo atteso (tipicamente 0–100), ma non è sempre il caso, quindi esiste la fase di normalizzazione.

### 4.2 NormalizeScore — perché serve e come funziona
Dopo aver eseguito tutti i plugin Score, entra in gioco la fase **NormalizeScore**. L'obiettivo è rendere i punteggi confrontabili fra plugin con scale diverse: la normalizzazione scala i punteggi di ciascun plugin in un intervallo comune (ad esempio 0–100) prima della combinazione ponderata.

Una formula di normalizzazione lineare (usata comunemente e descritta nella documentazione) è:

```
normalized = 100 * (raw - min_raw) / (max_raw - min_raw)
```

Dove `min_raw` e `max_raw` sono rispettivamente il valore minimo e massimo prodotti dallo stesso plugin su tutti i nodi valutati. Dopo questa trasformazione, il nodo con il valore raw uguale a `min_raw` riceve 0, quello con `max_raw` riceve 100 e gli altri sono scalati linearmente.

Fonti ufficiali indicano chiaramente che dopo la fase di NormalizeScore lo scheduler combinerà i punteggi normalizzati dei plugin in base ai pesi configurati. ([kubernetes.io], [scheduler-plugins]).

### 4.3 Combinazione dei punteggi (weights)
Una volta normalizzati, i punteggi di ciascun plugin sono combinati con una somma pesata:

```
score_totale(nodo) = Σ ( weight_plugin_i × normalized_score_plugin_i(nodo) )
```

I pesi (`weight_plugin_i`) sono definiti nella configurazione del scheduler (e.g. in `schedulerPolicy` o nella configurazione del framework dei plugin). Il nodo con `score_totale` più alto viene scelto per il binding.

### 4.4 Esempio numerico passo-passo

Immaginiamo 3 nodi (`N1`, `N2`, `N3`) e due plugin di scoring (`A` e `B`) che producono raw score come segue:

- Plugin A (raw): N1=30, N2=50, N3=10  
- Plugin B (raw): N1=400, N2=100, N3=300

**Step 1 — Normalize per plugin**

Plugin A: min=10, max=50  
- N1_A_norm = 100 * (30 - 10) / (50 - 10) = 100 * 20 / 40 = 50  
- N2_A_norm = 100 * (50 - 10) / 40 = 100  
- N3_A_norm = 100 * (10 - 10) / 40 = 0

Plugin B: min=100, max=400  
- N1_B_norm = 100 * (400 - 100) / 300 = 100  
- N2_B_norm = 100 * (100 - 100) / 300 = 0  
- N3_B_norm = 100 * (300 - 100) / 300 ≈ 66.67 → 67 (arrotondamento)

**Step 2 — Applichiamo i pesi** (esempio: peso A = 1, peso B = 2)

- N1_score_totale = 1×50 + 2×100 = 50 + 200 = **250**  
- N2_score_totale = 1×100 + 2×0 = 100 + 0 = **100**  
- N3_score_totale = 1×0 + 2×67 = 0 + 134 = **134**

**Risultato**: viene scelto `N1`, che ha il punteggio totale più alto (250), nonostante N2 avesse il valore raw più alto per il plugin A: la normalizzazione + i pesi hanno cambiato l'ordine finale.

> Questa dimostrazione mostra perché la normalizzazione è fondamentale: senza di essa, plugin con range numerico più ampio avrebbero dominato la classifica.

### 4.5 Dettagli pratici e caveat
- Alcuni plugin devono ritornare valori già nel range 0–100; altri producono valori in scale diverse e devono implementare `NormalizeScore` (via ScoreExtensions) per adattarsi. Se un plugin restituisce valori fuori range, il scheduler può segnalarlo come errore (vedi issue su GitHub relativo al range [0,100]).
- Il parametro `percentageOfNodesToScore` influisce su quanti nodi (tra quelli "factibili") saranno effettivamente valutati da molti plugin in cluster molto grandi; questo è un elemento di tuning delle prestazioni del kube-scheduler.

---

## 5) Binding e casi particolari

Dopo la scelta, il scheduler esegue il **binding** (aggiorna il Pod con `nodeName`). Se la bind fallisce (causa concorrenza, nodo non più valido), il ciclo di scheduling riparte. Se non esistono nodi factibili, il framework può ricorrere a meccanismi come **Preemption** per liberare risorse (rimuovendo pod a priorità inferiore), oppure a plugin PostFilter che provano strategie aggiuntive.

---

## 6) Come influenzare lo scheduling dal manifesto del Pod

- `nodeSelector` (vincolo semplice)  
- `nodeAffinity` (required vs preferred — le preferenze `preferredDuringSchedulingIgnoredDuringExecution` sono trattate come score)  
- `podAffinity` / `podAntiAffinity` (possono influenzare sia filter che score)  
- `tolerations` e `taints` (filter hard via taint/noSchedule o preferenze)  
- `topologySpreadConstraints` (per distribuire i pod su topologie come zone o nodi)

---

## 7) Riferimenti e immagini (fonti)

- Articolo di riferimento (testo e immagini): *Kubernetes Scheduling: How It Works and Key Factors* — PerfectScale. https://www.perfectscale.io/blog/kubernetes-scheduling
- Documentazione ufficiale: Scheduling Framework — Kubernetes. https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/  
- Alcuni approfondimenti su plugin e normalizzazione: scheduler-plugins KEPs e documentazione.

**Immagini hotlinked (Fonte: PerfectScale CDN):**  
- Diagramma generale: https://cdn.prod.website-files.com/635e4ccf77408db6bd802ae6/67973c6ae9d04f194a8141b8_AD_4nXe-MnVx9bQ4I6ZXMEzEhl6yQrZj1KdFboR32_9E4Aa3xWqTtDTbgRx3P72LBkTQmag_otjB6q-pfW_7Cwd46NUYjPJVwitYO_AvytfUtXcvjXXSoPFApbcnesYoEKWMVKaXXJ9UcA.jpeg  
- Filtering Phase: https://cdn.prod.website-files.com/635e4ccf77408db6bd802ae6/67973c6ab83dd57ac7dfc41f_AD_4nXer7VWzcpcsN6PaQbmRUIly_c4YTu2SPsUDpO3-w7uDsO533IsxSWAo05o7RAndcZKABXz4uSC8oMF89N9QMtec0qGQexe4UohmUeG7-tiJqrLQ20z40EyfuB0Rzfva82tPEO3OEQ.jpeg  
- Scoring Phase: https://cdn.prod.website-files.com/635e4ccf77408db6bd802ae6/67973c6aa7fa275459cde909_AD_4nXfCwGvbwj8_RfwIzpl46FXMmBeOxjkt3DlIJ_N2dC3RyWZajDK0aldyPrpgvEqwXFYyDdCeSqEsNrV9awExW8-hLriQ3gZJYUdi3OsgK9Rhdyvf5D0QCXDwNq1uwXyYWeW3IBroUA.jpeg

---

*Fine del file.*
