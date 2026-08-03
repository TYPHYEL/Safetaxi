# Plan d'Exécution : Correction Globale de SAFETAXI CAMEROUN

Ce document détaille l'ensemble des corrections nécessaires pour rendre le projet SAFETAXI CAMEROUN 100% opérationnel, sécurisé, sans erreur de compilation et prêt pour le déploiement.

---

## ⚠️ Notes Importantes & Décisions

> [!NOTE]
> - **Moyens de paiement** : Annulés (exclus du périmètre conformément à votre demande).
> - **Icône de l'application** : Sera configurée ensemble dès que le code sera 100% prêt et validé sans erreur.

---

## 1. Modifications Proposées

### Component 1: Frontend Mobile & Web (Flutter)

#### [MODIFY] [AndroidManifest.xml](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/android/app/src/main/AndroidManifest.xml)
- Ajouter la permission `<uses-permission android:name="android.permission.INTERNET" />` (indispensable pour les requêtes API).
- Ajouter les permissions de géolocalisation en arrière-plan (`ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`).

#### [MODIFY] [build.gradle.kts](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/android/app/build.gradle.kts)
- Définir `minSdk = 23` explicitement pour assurer la compatibilité avec `flutter_secure_storage` et `google_ml_kit`.

#### [MODIFY] [api_client.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/core/network/api_client.dart)
- Corriger `validateStatus` pour autoriser la levée d'exceptions HTTP 4xx, permettant à `_AuthInterceptor` de capturer les erreurs `401 Unauthorized` et d'exécuter le rafraîchissement automatique du token JWT.
- S'assurer que les méthodes HTTP génériques (`get`, `post`, `patch`, `delete`, `postMultipart`) sont publiques et correctement typées.

#### [MODIFY] [auth_provider.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/auth/presentation/providers/auth_provider.dart) & Écrans Auth
- Harmoniser le flux d'authentification OTP : gérer les réponses de `sendOtp` et `verifyOtp` pour gérer à la fois la connexion et l'auto-création de compte passager.

#### [MODIFY] [biometric_service.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/core/services/biometric_service.dart)
- Corriger la propriété `confidence` sur `Face` dans `google_ml_kit` v0.16.0 (remplacer par les probabilités disponibles ou les critères de qualité).

#### [MODIFY] Écrans Flutter avec erreurs d'import ou de typage
- [admin_dashboard_screen.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/admin/presentation/screens/admin_dashboard_screen.dart) & [admin_drivers_screen.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/admin/presentation/screens/admin_drivers_screen.dart) : Importer `apiClientProvider`.
- [sos_screen.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/sos/presentation/screens/sos_screen.dart) : Aligner le type de `_selectedType` avec `SosAlertType`.
- [rotation_management_screen.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/taxi/presentation/screens/rotation_management_screen.dart), [shift_handoff_screen.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/taxi/presentation/screens/shift_handoff_screen.dart), [shift_history_screen.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/taxi/presentation/screens/shift_history_screen.dart) : Remplacer les imports inexistants `app_colors.dart` / `app_text_styles.dart` par `app_theme.dart`, et corriger l'instanciation du client API.
- [driver_rotation_service.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/core/services/driver_rotation_service.dart), [my_taxis_screen.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/taxi/presentation/screens/my_taxis_screen.dart), [manage_drivers_screen.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/taxi/presentation/screens/manage_drivers_screen.dart), [taxi_create_screen.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/features/taxi/presentation/screens/taxi_create_screen.dart) : Utiliser les méthodes d'API corrigées.
- [widget_test.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/test/widget_test.dart) : Remplacer `MyApp` par `SafeTaxiApp`.

#### [MODIFY] [app_constants.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/core/constants/app_constants.dart)
- Ajuster la constante `baseUrl` selon la plateforme (ex: `10.0.2.2` pour l'émulateur Android).

---

### Component 2: Backend Django (Python & REST Framework)

#### [MODIFY] [users/views.py](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/backend/users/views.py)
- **Sécurité OTP** : Retirer l'affichage en clair du code OTP dans la réponse HTTP de `SendOtpView`.
- **Vérification OTP** : Mettre à jour `VerifyOtpView` pour créer automatiquement le compte `CustomUser` lors de la vérification OTP si l'utilisateur est un nouveau passager.
- **Permissions Admin** : Remplacer les vérifications impératives par des classes de permissions déclaratives DRF (`IsAdminUser`).

#### [MODIFY] [notifications/services.py](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/backend/notifications/services.py)
- Remplacer `messaging.send_multicast` par `messaging.send_each_for_multicast` pour assurer la compatibilité avec `firebase-admin>=6.0.0`.

#### [MODIFY] [safetaxi_backend/settings.py](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/backend/safetaxi_backend/settings.py)
- Sécuriser les clés secrètes et resserrer les règles CORS.

---

### Component 3: Synchronisation du Suivi GPS Temps Réel

#### [MODIFY] [location_service.dart](file:///c:/Users/YEMELI%20NGOUMELA/Desktop/safetaxi/lib/core/services/location_service.dart)
- Lors de l'envoi de la position GPS à Firebase Realtime Database, synchroniser également les coordonnées avec le backend Django (`/api/trips/<id>/location/`) pour maintenir la base de données centrale à jour.

---

## 2. Plan de Vérification

### Tests Automatisés & Compilation
- **Analyse Flutter** : Exécuter `flutter analyze` et vérifier l'absence totale d'erreurs (0 issues).
- **Vérification Backend** : Exécuter `python manage.py check` dans le dossier `backend/`.

### Vérification Manuelle & Intégration
- Vérifier que l'application s'exécute sans crash.
- Tester le flux complet Connexion/Inscription OTP et la géolocalisation.
