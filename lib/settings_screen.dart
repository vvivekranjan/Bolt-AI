// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:ai_chat_bot/providers/gemini.dart';

// class SettingsScreen extends ConsumerStatefulWidget {
//   const SettingsScreen({super.key});

//   @override
//   ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
// }

// class _SettingsScreenState extends ConsumerState<SettingsScreen> {
//   late TextEditingController _apiKeyController;
//   bool _obscureText = true;
//   bool _isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     _apiKeyController = TextEditingController();
//     _loadApiKey();
//   }

//   Future<void> _loadApiKey() async {
//     final apiKey = await ref.read(apiKeyProvider.future);
//     if (apiKey != null) {
//       _apiKeyController.text = apiKey;
//     }
//   }

//   Future<void> _saveApiKey() async {
//     final apiKey = _apiKeyController.text.trim();

//     if (apiKey.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please enter an API key')),
//       );
//       return;
//     }

//     setState(() => _isSaving = true);

//     try {
//       await ref.read(apiKeySetterProvider)(apiKey);
//       _apiKeyController.text = apiKey;

//       // Invalidate the gemini model provider to refresh with new API key
//       ref.invalidate(geminiModelProvider);
//       ref.invalidate(chatSessionProvider);

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('API key saved successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error saving API key: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       setState(() => _isSaving = false);
//     }
//   }

//   Future<void> _clearApiKey() async {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Clear API Key'),
//         content: const Text('Are you sure you want to remove the stored API key?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               try {
//                 await ref.read(apiKeySetterProvider)('');
//                 _apiKeyController.clear();
//                 ref.invalidate(geminiModelProvider);
//                 ref.invalidate(chatSessionProvider);

//                 if (mounted) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('API key removed'),
//                       backgroundColor: Colors.orange,
//                     ),
//                   );
//                 }
//               } catch (e) {
//                 if (mounted) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text('Error: $e'),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                 }
//               }
//             },
//             child: const Text('Clear', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _apiKeyController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Settings',
//         ),
//         backgroundColor: const Color.fromARGB(255, 14, 14, 14),
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       backgroundColor: const Color.fromARGB(255, 14, 14, 14),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Gemini API Configuration',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'Enter your Google Generative AI API key to enable the chat functionality.',
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.grey,
//                 ),
//               ),
//               const SizedBox(height: 24),
//               const Text(
//                 'API Key',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               TextField(
//                 controller: _apiKeyController,
//                 obscureText: _obscureText,
//                 decoration: InputDecoration(
//                   filled: true,
//                   fillColor: Colors.grey.shade900,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide(color: Colors.grey.shade700),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: const BorderSide(
//                       color: Color.fromARGB(255, 210, 28, 28),
//                     ),
//                   ),
//                   hintText: 'Paste your API key here',
//                   hintStyle: TextStyle(color: Colors.grey.shade600),
//                   suffixIcon: IconButton(
//                     icon: Icon(
//                       _obscureText ? Icons.visibility_off : Icons.visibility,
//                       color: Colors.grey.shade600,
//                     ),
//                     onPressed: () {
//                       setState(() => _obscureText = !_obscureText);
//                     },
//                   ),
//                 ),
//                 style: const TextStyle(color: Colors.white),
//               ),
//               const SizedBox(height: 24),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: _isSaving ? null : _saveApiKey,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color.fromARGB(255, 210, 28, 28),
//                     disabledBackgroundColor: Colors.grey.shade700,
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                   ),
//                   child: _isSaving
//                       ? const SizedBox(
//                           height: 20,
//                           width: 20,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             valueColor:
//                                 AlwaysStoppedAnimation(Colors.white),
//                           ),
//                         )
//                       : const Text(
//                           'Save API Key',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               SizedBox(
//                 width: double.infinity,
//                 child: OutlinedButton(
//                   onPressed: _clearApiKey,
//                   style: OutlinedButton.styleFrom(
//                     side: const BorderSide(
//                       color: Color.fromARGB(255, 210, 28, 28),
//                     ),
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                   ),
//                   child: const Text(
//                     'Clear API Key',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Color.fromARGB(255, 210, 28, 28),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 32),
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade900,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.grey.shade700),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'How to get your API Key:',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     _buildInstructionStep(
//                       1,
//                       'Go to Google AI Studio',
//                       'https://aistudio.google.com',
//                     ),
//                     const SizedBox(height: 8),
//                     _buildInstructionStep(
//                       2,
//                       'Click "Get API Key" button',
//                       'Create a new API key for your project',
//                     ),
//                     const SizedBox(height: 8),
//                     _buildInstructionStep(
//                       3,
//                       'Copy the API key',
//                       'And paste it in the field above',
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildInstructionStep(int number, String title, String description) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Container(
//           width: 24,
//           height: 24,
//           decoration: BoxDecoration(
//             color: const Color.fromARGB(255, 210, 28, 28),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Center(
//             child: Text(
//               '$number',
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.white,
//                 ),
//               ),
//               Text(
//                 description,
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey.shade500,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
