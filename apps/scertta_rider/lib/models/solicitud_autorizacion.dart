/// Modelo para solicitudes de autorización pendientes
/// 
/// MOCKUP - Datos de prueba
/// TODO: Reemplazar con datos reales de Supabase

class SolicitudAutorizacion {
  final String id;
  final String nombre;
  final String apellido;
  final String email;
  final String tipo; // 'equipo', 'conductor', 'socio'
  final DateTime fechaSolicitud;
  final String? telefono;
  final String? documentoUrl;

  SolicitudAutorizacion({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.tipo,
    required this.fechaSolicitud,
    this.telefono,
    this.documentoUrl,
  });

  String get nombreCompleto => '$nombre $apellido';
}

/// Datos de prueba (mockup)
class MockAutorizaciones {
  static List<SolicitudAutorizacion> getEquipoScertta() {
    return [
      SolicitudAutorizacion(
        id: '1',
        nombre: 'María',
        apellido: 'González',
        email: 'maria.gonzalez@ejemplo.com',
        tipo: 'equipo',
        fechaSolicitud: DateTime.now().subtract(const Duration(hours: 2)),
        telefono: '+54 11 1234-5678',
      ),
      SolicitudAutorizacion(
        id: '2',
        nombre: 'Carlos',
        apellido: 'Rodríguez',
        email: 'carlos.rodriguez@ejemplo.com',
        tipo: 'equipo',
        fechaSolicitud: DateTime.now().subtract(const Duration(hours: 5)),
        telefono: '+54 11 2345-6789',
      ),
      SolicitudAutorizacion(
        id: '3',
        nombre: 'Ana',
        apellido: 'Martínez',
        email: 'ana.martinez@ejemplo.com',
        tipo: 'equipo',
        fechaSolicitud: DateTime.now().subtract(const Duration(days: 1)),
        telefono: '+54 11 3456-7890',
      ),
    ];
  }

  static List<SolicitudAutorizacion> getConductoresPendientes() {
    return [
      SolicitudAutorizacion(
        id: '4',
        nombre: 'Juan',
        apellido: 'Pérez',
        email: 'juan.perez@ejemplo.com',
        tipo: 'conductor',
        fechaSolicitud: DateTime.now().subtract(const Duration(hours: 1)),
        telefono: '+54 11 4567-8901',
        documentoUrl: 'https://ejemplo.com/dni-juan.pdf',
      ),
      SolicitudAutorizacion(
        id: '5',
        nombre: 'Laura',
        apellido: 'Fernández',
        email: 'laura.fernandez@ejemplo.com',
        tipo: 'conductor',
        fechaSolicitud: DateTime.now().subtract(const Duration(hours: 3)),
        telefono: '+54 11 5678-9012',
        documentoUrl: 'https://ejemplo.com/dni-laura.pdf',
      ),
      SolicitudAutorizacion(
        id: '6',
        nombre: 'Diego',
        apellido: 'López',
        email: 'diego.lopez@ejemplo.com',
        tipo: 'conductor',
        fechaSolicitud: DateTime.now().subtract(const Duration(hours: 6)),
        telefono: '+54 11 6789-0123',
        documentoUrl: 'https://ejemplo.com/dni-diego.pdf',
      ),
      SolicitudAutorizacion(
        id: '7',
        nombre: 'Sofía',
        apellido: 'García',
        email: 'sofia.garcia@ejemplo.com',
        tipo: 'conductor',
        fechaSolicitud: DateTime.now().subtract(const Duration(days: 1)),
        telefono: '+54 11 7890-1234',
        documentoUrl: 'https://ejemplo.com/dni-sofia.pdf',
      ),
      SolicitudAutorizacion(
        id: '8',
        nombre: 'Martín',
        apellido: 'Sánchez',
        email: 'martin.sanchez@ejemplo.com',
        tipo: 'conductor',
        fechaSolicitud: DateTime.now().subtract(const Duration(days: 2)),
        telefono: '+54 11 8901-2345',
        documentoUrl: 'https://ejemplo.com/dni-martin.pdf',
      ),
    ];
  }

  static List<SolicitudAutorizacion> getSociosSolicitantes() {
    return [
      SolicitudAutorizacion(
        id: '9',
        nombre: 'Lucía',
        apellido: 'Torres',
        email: 'lucia.torres@ejemplo.com',
        tipo: 'socio',
        fechaSolicitud: DateTime.now().subtract(const Duration(minutes: 30)),
        telefono: '+54 11 9012-3456',
      ),
      SolicitudAutorizacion(
        id: '10',
        nombre: 'Roberto',
        apellido: 'Díaz',
        email: 'roberto.diaz@ejemplo.com',
        tipo: 'socio',
        fechaSolicitud: DateTime.now().subtract(const Duration(hours: 4)),
        telefono: '+54 11 0123-4567',
      ),
      SolicitudAutorizacion(
        id: '11',
        nombre: 'Valentina',
        apellido: 'Romero',
        email: 'valentina.romero@ejemplo.com',
        tipo: 'socio',
        fechaSolicitud: DateTime.now().subtract(const Duration(hours: 8)),
        telefono: '+54 11 1234-5678',
      ),
    ];
  }
}
