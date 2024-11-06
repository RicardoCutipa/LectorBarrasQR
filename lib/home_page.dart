import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'user_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Escáner de Usuarios',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final TextEditingController _searchController = TextEditingController(); // Controlador para el campo de texto

  File? _image;
  bool _isProcessing = false;
  String _message = '';
  UserModel? _userData;

  @override
  void dispose() {
    _barcodeScanner.close();
    _searchController.dispose(); // Limpiar el controlador al destruir el widget
    super.dispose();
  }

  Future<void> _searchUser(String userId) async {
    try {
      final docSnapshot = await _firestore.collection('usuarios').doc(userId).get();
      
      if (mounted) {
        if (docSnapshot.exists) {
          setState(() {
            _userData = UserModel.fromFirestore(docSnapshot);
            _message = '¡Usuario encontrado!';
          });
        } else {
          setState(() {
            _userData = null;
            _message = 'Usuario no encontrado en la base de datos';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userData = null;
          _message = 'Error al buscar usuario: $e';
        });
      }
      print('Error searching user: $e');
    }
  }

  Future<void> _processImage(String imagePath) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _message = 'Procesando imagen...';
      _userData = null;
    });

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        String barcode = barcodes.first.rawValue?.trim() ?? '';
        
        if (mounted) {
          setState(() {
            _message = 'Código encontrado: $barcode\nBuscando en la base de datos...';
          });
        }
        
        if (barcode.isNotEmpty) {
          await _searchUser(barcode);
        } else {
          if (mounted) {
            setState(() {
              _message = 'Código leído está vacío';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _message = 'No se encontró ningún código de barras';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Error al procesar la imagen: $e';
        });
      }
      print('Error processing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      
      if (pickedFile != null && mounted) {
        setState(() {
          _image = File(pickedFile.path);
          _message = 'Imagen seleccionada, iniciando procesamiento...';
        });
        await _processImage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Error al obtener la imagen: $e';
        });
      }
      print('Error getting image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner de Usuarios'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Seleccionar imagen',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _getImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Tomar Foto'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _getImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galería'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Ingrese el ID de usuario',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Llama a la función de búsqueda usando el valor ingresado en el campo de texto
                          String userId = _searchController.text.trim();
                          if (userId.isNotEmpty) {
                            _searchUser(userId);
                          } else {
                            setState(() {
                              _message = 'Por favor, ingrese un ID de usuario válido';
                            });
                          }
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar Usuario'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_image != null) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(
                      _image!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
              if (_isProcessing) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  color: _userData != null ? Colors.green[100] : Colors.orange[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _message,
                      style: TextStyle(
                        fontSize: 16,
                        color: _userData != null ? Colors.green[900] : Colors.orange[900],
                      ),
                    ),
                  ),
                ),
              ],
              if (_userData != null) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información del Usuario',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('ID:', _userData!.id),
                        _buildInfoRow('Nombre:', _userData!.nombre),
                        _buildInfoRow('Apellido:', _userData!.apellido),
                        _buildInfoRow('Nacimiento:', _userData!.nacimiento),
                        _buildInfoRow('Sexo:', _userData!.sexo),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
