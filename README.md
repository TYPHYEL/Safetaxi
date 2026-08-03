# 🚕 SAFETAXI CAMEROUN — Application Mobile Flutter

> Plateforme de sécurisation des taxis urbains conventionnels de Yaoundé

---

## 📱 Aperçu

SAFETAXI CAMEROUN est une application mobile Flutter conçue spécifiquement pour le contexte réel des taxis camerounais. Elle n'est **pas** une copie d'Uber ou Bolt — elle répond à la réalité locale : taxis pris au bord de la route, passagers partagés, multi-chauffeurs, alertes SOS discrètes.

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── constants/     # AppConstants, AppRoutes
│   ├── error/         # Failures, Exception parsing
│   ├── network/       # ApiClient (Dio + JWT), FirebaseService
│   └── utils/         # OfflineService (Hive)
│
├── features/
│   ├── auth/          # Login, OTP, Register, Home Passager/Chauffeur
│   ├── taxi/          # Detail, Liste, Création, Gestion chauffeurs
│   ├── trajet/        # Scan QR, Trajet actif, Passagers, Historique
│   ├── sos/           # SOS Screen, Incident Screen
│   ├── map/           # Google Maps + Firebase RT, Notation, Admin
│   ├── notation/      # Rating system
│   └── profil/        # Profil, Trust Score, Settings, Notifications
│
├── shared/
│   ├── theme/         # AppTheme, AppColors, AppTextStyles
│   └── widgets/       # SafeAvatar, TrustBadge
│
├── config/
│   └── router/        # GoRouter avec redirections par rôle
│
└── main.dart
```

### Pattern par feature
```
feature/
  data/
    models/            # JSON serialization
    repositories/      # Implémentation repos
  domain/
    entities/          # Classes pures
    usecases/          # Logique métier
  presentation/
    providers/         # Riverpod StateNotifier
    screens/           # Widgets page
    widgets/           # Widgets réutilisables
```

---

## 🎨 Design System

| Couleur | Usage | Hex |
|---------|-------|-----|
| Primary (Vert) | Actions principales, GPS actif | `#00C896` |
| Danger (Rouge) | SOS, alertes | `#FF3B30` |
| Driver (Bleu) | Interface chauffeur | `#4A9EFF` |
| Owner (Orange) | Propriétaire, rating | `#FFB347` |
| Admin (Violet) | Admin panel | `#BB86FC` |
| Background | Fond app | `#0A0E1A` |

**Police** : Archivo (Regular, Medium, SemiBold, Bold, Black)

---

## 👥 Rôles et navigation

| Rôle | Home | Accès |
|------|------|-------|
| Passager | `HomePassengerScreen` | Scan, Carte, Historique, SOS |
| Chauffeur | `HomeDriverScreen` | Service toggle, Trajet, SOS |
| Propriétaire | `MyTaxisScreen` | Taxis, Chauffeurs |
| Admin | `AdminDashboardScreen` | Validation, Stats, Alertes |

---

## 🔧 Installation

### Prérequis
- Flutter 3.19+
- Dart 3.3+
- Android Studio / Xcode
- Compte Firebase
- Clé API Google Maps

### Setup

```bash
# 1. Cloner
git clone https://github.com/votre-org/safetaxi-cameroun.git
cd safetaxi-cameroun

# 2. Dépendances
flutter pub get

# 3. Firebase
# - Créer projet sur console.firebase.google.com
# - Télécharger google-services.json (Android)
# - Télécharger GoogleService-Info.plist (iOS)
# - Placer dans les dossiers appropriés

# 4. Variables d'environnement
# Créer lib/core/constants/env.dart :
# const googleMapsKey = 'YOUR_KEY';
# const qwenApiKey = 'YOUR_KEY';

# 5. Build runner
flutter pub run build_runner build --delete-conflicting-outputs

# 6. Lancer
flutter run
```

---

## 🗺️ Écrans implémentés (20/20)

| # | Écran | Statut |
|---|-------|--------|
| 1 | Splash Screen | ✅ Animé, tri-couleur CMR |
| 2 | Onboarding (4 slides) | ✅ |
| 3 | Login (OTP SMS) | ✅ |
| 4 | Register (multi-rôles) | ✅ |
| 5 | Home Passager | ✅ |
| 6 | Home Chauffeur | ✅ |
| 7 | Carte Temps Réel | ✅ Google Maps + Firebase |
| 8 | Taxi Details + QR | ✅ |
| 9 | Passagers présents (live) | ✅ Firebase RT |
| 10 | SOS (maintien bouton) | ✅ |
| 11 | Historique Trajets | ✅ |
| 12 | Profil | ✅ |
| 13 | Gestion Chauffeurs | ✅ |
| 14 | Gestion Taxi | ✅ |
| 15 | Notifications | ✅ |
| 16 | Admin Dashboard | ✅ |
| 17 | Signalement Incident | ✅ |
| 18 | Validation Chauffeur (Admin) | ✅ |
| 19 | Trust Score | ✅ |
| 20 | Paramètres | ✅ |

---

## 🔑 Fonctionnalités clés

### Trajet collectif camerounais
1. Passager arrête un taxi en bord de route
2. Scan QR code ou saisie du code taxi
3. Trajet numérique créé / rejoint
4. Passagers visibles (prénom + photo uniquement)
5. GPS temps réel via Firebase Realtime DB
6. Descente enregistrée avec position

### SOS discret
- Pression longue du bouton dédié (3 secondes)
- Triple pression bouton volume (natif)
- Position GPS capturée et envoyée
- Contacts d'urgence alertés par FCM
- Enregistrement de l'incident en base

### Trust Score
```
Score = (Note moyenne × 0.40) 
      + (Trajets sans incident × 0.30)
      + (Ancienneté × 0.15)
      + (CNI vérifié × 0.15)
```

### Mode hors-ligne
- Cache Hive pour taxis, trajets, profil
- Queue de synchronisation différée
- Reprise auto au retour de la connexion

---

## 📡 Stack

| Couche | Tech |
|--------|------|
| State | Riverpod 2 + StateNotifier |
| Navigation | GoRouter 13 |
| HTTP | Dio + JWT auto-refresh |
| Temps réel | Firebase Realtime Database |
| Push | Firebase Cloud Messaging |
| Cartes | Google Maps Flutter |
| Cache | Hive Flutter |
| QR | mobile_scanner + qr_flutter |
| Auth | flutter_secure_storage |

---

## 🔗 Prochaine étape

→ **Backend Django** (voir `/backend/README.md`)
→ **Connexion Flutter ↔ Django** via variables d'environnement

---

## 📋 TODO Production

- [ ] Remplacer mock data par vrais endpoints
- [ ] Intégrer google-services.json Firebase réel  
- [ ] Configurer clé Google Maps
- [ ] Implémenter VolumeButtonReceiver Android natif
- [ ] Ajouter tests unitaires (coverage > 80%)
- [ ] CI/CD GitHub Actions
- [ ] Déploiement Play Store / App Store

---

*SAFETAXI CAMEROUN — Vos trajets. Votre sécurité.* 🇨🇲
