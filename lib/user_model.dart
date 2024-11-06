import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String nombre;
  final String apellido;
  final String nacimiento;
  final String sexo;

  UserModel({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.nacimiento,
    required this.sexo,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      apellido: data['apellido'] ?? '',
      nacimiento: data['nacimiento'] ?? '',
      sexo: data['sexo'] ?? '',
    );
  }
}