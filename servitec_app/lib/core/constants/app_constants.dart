class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'ServiTec';
  static const String appVersion = '1.0.0';

  // Roles
  static const String roleClient = 'cliente';
  static const String roleTechnician = 'tecnico';
  static const String roleAdmin = 'admin';

  // Service Categories
  static const List<String> serviceCategories = [
    'electricidad',
    'plomeria',
    'limpieza',
    'pintura',
    'carpinteria',
    'cerrajeria',
    'aire_acondicionado',
    'electrodomesticos',
    'jardineria',
    'otro',
  ];

  static const Map<String, String> categoryLabels = {
    'electricidad': 'Electricidad',
    'plomeria': 'Plomería',
    'limpieza': 'Limpieza',
    'pintura': 'Pintura',
    'carpinteria': 'Carpintería',
    'cerrajeria': 'Cerrajería',
    'aire_acondicionado': 'Aire Acondicionado',
    'electrodomesticos': 'Electrodomésticos',
    'jardineria': 'Jardinería',
    'otro': 'Otro',
  };

  static const Map<String, String> categoryIcons = {
    'electricidad': '⚡',
    'plomeria': '🔧',
    'limpieza': '🧹',
    'pintura': '🎨',
    'carpinteria': '🪚',
    'cerrajeria': '🔑',
    'aire_acondicionado': '❄️',
    'electrodomesticos': '🔌',
    'jardineria': '🌿',
    'otro': '📋',
  };

  // Service States
  static const String statusPending = 'pendiente';
  static const String statusAssigned = 'asignado';
  static const String statusInProgress = 'en_progreso';
  static const String statusCompleted = 'completado';
  static const String statusCancelled = 'cancelado';
  static const String statusPaymentPending = 'pago_pendiente';
  static const String statusPaid = 'pagado';

  // Urgency
  static const String urgencyNormal = 'normal';
  static const String urgencyUrgent = 'urgente';

  // Assignment Types
  static const String assignmentClient = 'cliente';
  static const String assignmentAutomatic = 'automatica';
  static const String assignmentAdmin = 'admin';

  // Limits
  static const int maxPhotosPerService = 5;
  static const int maxDescriptionLength = 500;
  static const double maxPhotoSizeMB = 5.0;
  static const double baseDistanceKm = 10.0;

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String servicesCollection = 'servicios';
  static const String reviewsCollection = 'resenas';
  static const String configCollection = 'configuracion';
  static const String messagesSubcollection = 'mensajes';
  static const String transactionsCollection = 'transacciones';
}
