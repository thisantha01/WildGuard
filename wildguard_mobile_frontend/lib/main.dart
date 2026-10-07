import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'repositories/incident_repository_impl.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/connectivity_service.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'viewmodels/auth_manager.dart';
import 'viewmodels/offline_sync_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean Architecture Dependency Injection
  final databaseService = DatabaseService();
  final apiService = ApiService();
  final locationService = LocationService();
  final connectivityService = ConnectivityService();

  final incidentRepository = IncidentRepositoryImpl(
    databaseService: databaseService,
    apiService: apiService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthManager(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => OfflineSyncManager(
            repository: incidentRepository,
            locationService: locationService,
            connectivityService: connectivityService,
          )..loadIncidents(),
        ),
      ],
      child: const WildGuardApp(),
    ),
  );
}

class WildGuardApp extends StatelessWidget {
  const WildGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
