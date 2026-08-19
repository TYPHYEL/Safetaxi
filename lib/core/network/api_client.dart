// lib/core/network/api_client.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(seconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-App-Version': '1.0.0',
        'X-Platform': 'flutter',
      },
    ));

    // Only 2xx are success; 4xx/5xx raise DioException so _AuthInterceptor can handle 401.
    _dio.options.validateStatus =
        (status) => status != null && status >= 200 && status < 300;

    _dio.interceptors.addAll([
      _AuthInterceptor(_storage, _dio),
      _LogInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  // ─── Auth ──────────────────────────────────────────────
  Future<Response> login(Map<String, dynamic> data) =>
      _dio.post('/auth/login/', data: data);

  Future<Response> firebaseLogin(Map<String, dynamic> data) =>
      _dio.post('/auth/firebase/login/', data: data);

  Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('/auth/register/', data: data);

  Future<Response> sendOtp(String phone) =>
      _dio.post('/auth/otp/send/', data: {'phone': phone});

  Future<Response> verifyOtp(Map<String, dynamic> data) =>
      _dio.post('/auth/otp/verify/', data: data);

  Future<Response> verifyOtpWithFiles(dynamic formData) {
    final data = formData is FormData
        ? formData
        : FormData.fromMap(Map<String, dynamic>.from(formData));
    return _dio.post('/auth/otp/verify/', data: data);
  }

  // ─── Document Validation (OCR) ─────────────────────────────
  Future<Response> validateCni(File cniPhoto) {
    final formData = FormData.fromMap({
      'cni_photo': MultipartFile.fromFileSync(cniPhoto.path),
    });
    return _dio.post('/document-validation/validate_cni/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> validateLicense(File licensePhoto) {
    final formData = FormData.fromMap({
      'license_photo': MultipartFile.fromFileSync(licensePhoto.path),
    });
    return _dio.post('/document-validation/validate_license/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> validateVehicle(File vehiclePhoto) {
    final formData = FormData.fromMap({
      'vehicle_photo': MultipartFile.fromFileSync(vehiclePhoto.path),
    });
    return _dio.post('/document-validation/validate_vehicle/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> validateRegistration(
      File registrationPhoto, String plateNumber) {
    final formData = FormData.fromMap({
      'registration_photo': MultipartFile.fromFileSync(registrationPhoto.path),
      'plate_number': plateNumber,
    });
    return _dio.post('/document-validation/validate_registration/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> compareDocuments(File cniPhoto, File licensePhoto) {
    final formData = FormData.fromMap({
      'cni_photo': MultipartFile.fromFileSync(cniPhoto.path),
      'license_photo': MultipartFile.fromFileSync(licensePhoto.path),
    });
    return _dio.post('/document-validation/compare_documents/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  // ─── Intelligent Document Verification (EasyOCR) ─────────────
  Future<Response> verifyCniDocument(File cniPhoto, {String? expectedName}) {
    final formData = FormData.fromMap({
      'cni_photo': MultipartFile.fromFileSync(cniPhoto.path),
      if (expectedName != null) 'expected_name': expectedName,
    });
    return _dio.post('/verification/verify-cni/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> verifyLicensePlate(File vehiclePhoto, {String? expectedPlate}) {
    final formData = FormData.fromMap({
      'vehicle_photo': MultipartFile.fromFileSync(vehiclePhoto.path),
      if (expectedPlate != null) 'expected_plate': expectedPlate,
    });
    return _dio.post('/verification/verify-license-plate/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> verifyVehicleDocument(File vehicleDoc, {String? expectedPlate}) {
    final formData = FormData.fromMap({
      'vehicle_doc': MultipartFile.fromFileSync(vehicleDoc.path),
      if (expectedPlate != null) 'expected_plate': expectedPlate,
    });
    return _dio.post('/verification/verify-vehicle-doc/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> checkImageQuality(File image) {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromFileSync(image.path),
    });
    return _dio.post('/verification/check-quality/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> compareDocumentsVerification(File doc1, File doc2) {
    final formData = FormData.fromMap({
      'doc1': MultipartFile.fromFileSync(doc1.path),
      'doc2': MultipartFile.fromFileSync(doc2.path),
    });
    return _dio.post('/verification/compare-documents/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> detectFace(File image) {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromFileSync(image.path),
    });
    return _dio.post('/verification/detect-face/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> generateFaceEmbedding(File image) {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromFileSync(image.path),
    });
    return _dio.post('/verification/generate-face-embedding/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> verifyFaceMatch(File image1, File image2, {double threshold = 0.4}) {
    final formData = FormData.fromMap({
      'image1': MultipartFile.fromFileSync(image1.path),
      'image2': MultipartFile.fromFileSync(image2.path),
      'threshold': threshold,
    });
    return _dio.post('/verification/verify-face-match/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> verifyFaceWithEmbedding(File image, List<double> embedding, {double threshold = 0.4}) {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromFileSync(image.path),
      'embedding': embedding,
      'threshold': threshold,
    });
    return _dio.post('/verification/verify-face-embedding/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response> refreshToken(String refresh) =>
      _dio.post('/auth/token/refresh/', data: {'refresh': refresh});

  Future<Response> getProfile() => _dio.get('/auth/profile/');

  Future<Response> updateProfile(Map<String, dynamic> data) =>
      _dio.patch('/auth/profile/', data: data);

  Future<Response> updateProfilePhoto(File photo) {
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromFileSync(photo.path),
    });
    return _dio.patch('/auth/profile/',
        data: formData, options: Options(contentType: 'multipart/form-data'));
  }

  // Generic HTTP helpers
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data, Options? options}) =>
      _dio.post(path, data: data, options: options);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path, {dynamic data}) =>
      _dio.delete(path, data: data);

  // Generic multipart upload
  Future<Response> postMultipart(String path,
          {Map<String, dynamic>? data,
          Map<String, MultipartFile>? files,
          Options? options}) =>
      _dio.post(
        path,
        data: FormData.fromMap({...?data, ...?files}),
        options: options ?? Options(contentType: 'multipart/form-data'),
      );

  // ─── Taxis ─────────────────────────────────────────────
  Future<Response> getTaxis({int page = 1}) =>
      _dio.get('/taxis/', queryParameters: {'page': page});

  Future<Response> getTaxiById(String id) => _dio.get('/taxis/$id/');

  Future<Response> getNearbyTaxis(double lat, double lng,
          {double radius = 2.0}) =>
      _dio.get('/taxis/nearby/',
          queryParameters: {'lat': lat, 'lng': lng, 'radius': radius});

  Future<Response> createTaxi(Map<String, dynamic> data, {File? photo}) {
    if (photo != null) {
      return postMultipart('/taxis/',
          data: data, files: {'image': MultipartFile.fromFileSync(photo.path)});
    }
    return _dio.post('/taxis/', data: data);
  }

  Future<Response> getTaxiQrCode(String id) => _dio.get('/taxis/$id/qrcode/');

  // ─── Trajets ───────────────────────────────────────────
  Future<Response> createTrip(Map<String, dynamic> data) =>
      _dio.post('/trips/', data: data);

  Future<Response> startTrip(String tripId, Map<String, dynamic> data) =>
      _dio.post('/trips/$tripId/start/', data: data);

  Future<Response> joinTrip(String tripId, Map<String, dynamic> data) =>
      _dio.post('/trips/$tripId/join/', data: data);

  Future<Response> leaveTrip(String tripId) =>
      _dio.post('/trips/$tripId/leave/');

  Future<Response> endTrip(String tripId) => _dio.post('/trips/$tripId/end/');

  Future<Response> getTripPassengers(String tripId) =>
      _dio.get('/trips/$tripId/passengers/');

  Future<Response> getTripHistory({int page = 1}) =>
      _dio.get('/trips/history/', queryParameters: {'page': page});

  Future<Response> getActiveTrip() => _dio.get('/trips/active/');

  // ─── Dépôts (Courses privées) ─────────────────────────────
  Future<Response> calculateDepositFare(Map<String, dynamic> data) =>
      _dio.post('/deposits/calculate_fare/', data: data);

  Future<Response> createDeposit(Map<String, dynamic> data) =>
      _dio.post('/deposits/create_deposit/', data: data);

  Future<Response> acceptDeposit(String depositId) =>
      _dio.post('/deposits/$depositId/accept/');

  Future<Response> rejectDeposit(String depositId) =>
      _dio.post('/deposits/$depositId/reject/');

  Future<Response> startDeposit(String depositId) =>
      _dio.post('/deposits/$depositId/start/');

  Future<Response> completeDeposit(String depositId) =>
      _dio.post('/deposits/$depositId/complete/');

  Future<Response> cancelDeposit(String depositId) =>
      _dio.post('/deposits/$depositId/cancel/');

  Future<Response> getDeposit(String depositId) =>
      _dio.get('/deposits/$depositId/');

  Future<Response> getMyDeposits() => _dio.get('/deposits/');

  // ─── SOS ───────────────────────────────────────────────
  Future<Response> sendSos(Map<String, dynamic> data) =>
      _dio.post('/sos/alert/', data: data);

  Future<Response> resolveSos(String sosId) =>
      _dio.post('/sos/$sosId/resolve/');

  // ─── Notation ──────────────────────────────────────────
  Future<Response> rateUser(Map<String, dynamic> data) =>
      _dio.post('/ratings/rate/', data: data);

  Future<Response> getUserRatings(String userId) =>
      _dio.get('/ratings/user/$userId/');

  Future<Response> getMyTrustScore() => _dio.get('/ratings/my-score/');

  // ─── Chauffeurs ────────────────────────────────────────
  Future<Response> registerDriver(Map<String, dynamic> data) =>
      _dio.post('/drivers/register/', data: data);

  Future<Response> uploadDriverDoc(String docType, dynamic formData) =>
      _dio.post('/driver-docs/',
          data: formData,
          options: Options(
            contentType: 'multipart/form-data',
            sendTimeout: const Duration(seconds: AppConstants.uploadTimeout),
            receiveTimeout: const Duration(seconds: AppConstants.uploadTimeout),
          ));

  Future<Response> activateShift(String driverId) =>
      _dio.post('/drivers/$driverId/activate/');

  Future<Response> deactivateShift(String driverId) =>
      _dio.post('/drivers/$driverId/deactivate/');

  Future<Response> verifyBiometric(Map<String, dynamic> data) =>
      _dio.post('/biometric/', data: data);

  Future<Response> createBiometricRequest(FormData formData) =>
      _dio.post('/biometric/',
          data: formData, options: Options(contentType: 'multipart/form-data'));

  // ─── Admin ─────────────────────────────────────────────
  Future<Response> getPendingDrivers() => _dio.get('/admin/drivers/pending/');

  Future<Response> approveDriver(String driverId) =>
      _dio.post('/admin/drivers/$driverId/approve/');

  Future<Response> rejectDriver(String driverId, String reason) =>
      _dio.post('/admin/drivers/$driverId/reject/', data: {'reason': reason});

  Future<Response> getDashboardStats() => _dio.get('/admin/dashboard/');

  // ─── Rotations ─────────────────────────────────────────
  Future<Response> getRotations() => _dio.get('/rotations/');
  Future<Response> createRotation(Map<String, dynamic> data) =>
      _dio.post('/rotations/', data: data);
  Future<Response> updateRotation(String id, Map<String, dynamic> data) =>
      _dio.patch('/rotations/$id/', data: data);
  Future<Response> deleteRotation(String id) => _dio.delete('/rotations/$id/');
  Future<Response> activateRotation(String id) =>
      _dio.post('/rotations/$id/activate/');
  Future<Response> deactivateRotation(String id) =>
      _dio.post('/rotations/$id/deactivate/');

  // ─── IA ────────────────────────────────────────────────
  Future<Response> analyzeRisk(Map<String, dynamic> data) =>
      _dio.post('/ai/analyze-risk/', data: data);

  Future<Response> chatAssistant(List<Map<String, dynamic>> messages) =>
      _dio.post('/ai/chat/', data: {'messages': messages});

  // ─── Incidents ─────────────────────────────────────────
  Future<Response> reportIncident(Map<String, dynamic> data) =>
      _dio.post('/incidents/report/', data: data);

  Future<Response> getIncidents({int page = 1}) =>
      _dio.get('/incidents/', queryParameters: {'page': page});
}

// ─── Intercepteur JWT ────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refresh = await _storage.read(key: AppConstants.refreshTokenKey);
        if (refresh == null) {
          handler.next(err);
          return;
        }
        final resp =
            await _dio.post('/auth/token/refresh/', data: {'refresh': refresh});
        final newToken = resp.data['access'] as String;
        await _storage.write(key: AppConstants.accessTokenKey, value: newToken);

        // Retry la requête originale
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        final retried = await _dio.fetch(opts);
        handler.resolve(retried);
      } catch (_) {
        await _storage.deleteAll();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log.d('→ ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log.d('← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log.e('✗ ${err.response?.statusCode} ${err.requestOptions.path}',
        error: err.message);
    handler.next(err);
  }
}
