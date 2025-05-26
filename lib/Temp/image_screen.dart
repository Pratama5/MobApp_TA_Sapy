// import 'package:flutter/material.dart';
// import 'package:wavemark_app_v1/Etc/bottom_nav.dart';
// import 'package:wavemark_app_v1/Library/image_gallery_preview.dart';

// class ImageScreen extends StatelessWidget {
//   final bool isPicker;
//   const ImageScreen({super.key, this.isPicker = false});

//   final List<String> imagePaths = const [
//     'assets/Watermark_1.png',
//     'assets/Watermark_2.png',
//     'assets/Watermark_3.png',
//     'assets/Watermark_4.png',
//     'assets/Watermark_5.png',
//     'assets/Watermark_6.png',
//     'assets/Watermark_7.png',
//     'assets/Watermark_8.png',
//     'assets/Watermark_9.png',
//     'assets/Watermark_10.png',
//     'assets/Logo.png',
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5E8E4),
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         automaticallyImplyLeading: true,
//         iconTheme: const IconThemeData(color: Color(0xFF411530)),
//         title: const Text(
//           'Image',
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//             color: Color(0xFF411530),
//           ),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//         child: GridView.builder(
//           itemCount: imagePaths.length,
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             mainAxisSpacing: 20,
//             crossAxisSpacing: 16,
//             childAspectRatio: 0.72,
//           ),
//           itemBuilder: (context, index) {
//             final path = imagePaths[index];
//             return GestureDetector(
//               onTap: () {
//                 if (isPicker) {
//                   Navigator.pop(
//                     context,
//                     path,
//                   ); // ✅ kirim path ke EmbeddingScreen
//                 } else {
//                   // 🔁 Tetap buka preview kalau buka dari LibraryScreen
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => ImageGalleryPreview(
//                         imagePaths: imagePaths,
//                         initialIndex: index,
//                       ),
//                     ),
//                   );
//                 }
//               },
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: Image.asset(
//                   path,
//                   fit: BoxFit.cover,
//                   errorBuilder: (_, __, ___) => Container(
//                     color: Colors.grey[300],
//                     child: const Icon(Icons.image, size: 40),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//       bottomNavigationBar: const BottomNavBar(currentRoute: '/library'),
//     );
//   }
// }
