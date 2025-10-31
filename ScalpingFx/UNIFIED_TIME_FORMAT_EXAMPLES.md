# Format Unifié des Plages Horaires

## 🎯 Nouveau Format Unifié

Tous les filtres de temps supportent maintenant le format unifié avec précision minute :

### Formats Acceptés

1. **Format complet** : `"08:30-10:45; 15:30-18:00"`
2. **Format compact** : `"0830-1045;1530-1800"`
3. **Plages multiples** : `"08:30-10:45; 13:00-14:30; 16:00-18:00"`
4. **Traversée minuit** : `"22:00-02:00"` ou `"2200-0200"`

## 📋 Exemples d'Utilisation

### RiskMultiplierManager

```mql5
// Nouveau format unifié
RiskMultiplierManager riskMgr;
riskMgr.InitializeUnified(true, "08:30-10:45; 15:30-18:00", 2.0, "Morning & Afternoon Boost");

// Ou format compact
riskMgr.InitializeUnified(true, "0830-1045;1530-1800", 2.0, "Morning & Afternoon Boost");

// Plages traversant minuit
riskMgr.InitializeUnified(true, "22:00-02:00", 1.5, "Overnight Boost");
```

### TimeFilter

```mql5
TimeFilter filter;
filter.SetHourFilter(true, "08:30-10:45; 15:30-18:00");
if(filter.IsTradingAllowed()) {
    // Trading autorisé
}
string info = filter.GetInfo(); // "TimeFilter: ON [08:30-10:45; 15:30-18:00] | ACTIVE"
```

### TimeRangeFilter

```mql5
TimeRangeFilter rangeFilter;
rangeFilter.SetFilter(true, "08:30-10:45; 15:30-18:00");
if(rangeFilter.IsTradingAllowed()) {
    // Trading autorisé
}
```

### TimeMinuteFilter

```mql5
TimeMinuteFilter minuteFilter;
minuteFilter.SetFilter(true, "08:30-10:45; 15:30-18:00");
if(minuteFilter.IsTradingAllowed()) {
    // Trading autorisé
}
```

## 🔧 Configuration dans les EAs

### ForexScalper.mq5

```mql5
// Ancien format (supprimé)
// #define START_HOUR             7
// #define END_HOUR               19
// #define RISK_MULT_START_HOUR   13
// #define RISK_MULT_START_MINUTE 0
// #define RISK_MULT_END_HOUR     17
// #define RISK_MULT_END_MINUTE   0

// Nouveau format unifié
#define TRADING_TIME_RANGES    "07:00-19:00"
#define RISK_MULT_TIME_RANGES  "13:00-17:00"
```

### ConfigLoader.mqh

```mql5
// Ancien format (supprimé)
// SetupRiskMultiplier(true, 13, 0, 17, 0, 2.0, "London-NY Overlap");
// SetupTradingHours(7, 21);

// Nouveau format unifié
SetupRiskMultiplier(true, "13:00-17:00", 2.0, "London-NY Overlap");
SetupTradingHours("07:00-21:00");

// Exemples avec plages multiples
SetupTradingHours("08:30-10:45; 15:30-18:00");
SetupTradingHours("0830-1045;1530-1800");  // Format compact
```

## ✅ Rétro-compatibilité

L'ancien format est toujours supporté pour la rétro-compatibilité :

```mql5
// Ancien format (toujours fonctionnel)
riskMgr.Initialize(true, 13, 0, 17, 0, 2.0, "London-NY Overlap");

// TradingTimeManager utilise automatiquement le nouveau format si disponible
// Sinon, il fallback vers l'ancien format
```

## 🎨 Affichage Graphique

Tous les filtres exposent maintenant une méthode `GetInfo()` pour l'affichage :

```mql5
string info = riskMgr.GetInfo();
// Résultat: "Risk Mult: x2.0 [13:00-17:00] | ACTIVE"

string filterInfo = timeFilter.GetInfo();
// Résultat: "TimeFilter: ON [08:30-10:45; 15:30-18:00] | ACTIVE"
```

## 🚀 Avantages

1. **Format unifié** : Même syntaxe pour tous les filtres
2. **Précision minute** : Support des minutes, pas seulement des heures
3. **Plages multiples** : Plusieurs périodes dans une seule configuration
4. **Traversée minuit** : Support des plages overnight
5. **Format compact** : Syntaxe raccourcie pour les cas simples
6. **Rétro-compatible** : L'ancien format fonctionne toujours
7. **Affichage graphique** : Méthode `GetInfo()` pour tous les filtres
