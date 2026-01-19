import 'package:flutter/material.dart';
import '../models/tip.dart';
import '../widgets/common_scaffold.dart';

typedef TipStatusCallback = void Function(String tipKey, int status);

class TipDetailScreen extends StatefulWidget {
  final String tipKey;
  final Tip tip;
  final TipStatusCallback onStatusChanged;

  const TipDetailScreen({
    super.key,
    required this.tipKey,
    required this.tip,
    required this.onStatusChanged,
  });

  @override
  State<TipDetailScreen> createState() => _TipDetailScreenState();
}

class _TipDetailScreenState extends State<TipDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.tip.status == 0) {
        widget.onStatusChanged(widget.tipKey, 1);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStatusChanged(widget.tipKey, 1);
    });
    super.dispose();
  }

  // Функция для парсинга текста и вставки фотографий
  List<Widget> _parseTipContent(String tipText, List<String> images) {
    final List<Widget> widgets = [];
    
    // Регулярное выражение для поиска маркеров [img1], [img2], [1], [2] и т.д.
    final RegExp imagePattern = RegExp(r'\[(img)?(\d+)\]');
    
    // Находим все маркеры в тексте
    final matches = imagePattern.allMatches(tipText).toList();
    
    if (matches.isEmpty) {
      // Если нет маркеров, просто возвращаем весь текст
      return [_buildTextSection(tipText)];
    }
    
    // Начинаем с начала текста
    int currentIndex = 0;
    
    for (final match in matches) {
      // Добавляем текст перед маркером
      final textBefore = tipText.substring(currentIndex, match.start);
      if (textBefore.isNotEmpty) {
        widgets.add(_buildTextSection(textBefore));
      }
      
      // Добавляем изображение
      final imageIndexStr = match.group(2);
      if (imageIndexStr != null) {
        final imageIndex = int.parse(imageIndexStr) - 1; // Преобразуем в 0-based индекс
        if (imageIndex >= 0 && imageIndex < images.length) {
          widgets.add(_buildImageWidget(images[imageIndex]));
        }
      }
      
      // Перемещаем указатель на конец маркера
      currentIndex = match.end;
    }
    
    // Добавляем оставшийся текст после последнего маркера
    final remainingText = tipText.substring(currentIndex);
    if (remainingText.isNotEmpty) {
      widgets.add(_buildTextSection(remainingText));
    }
    
    return widgets;
  }

  // Метод для построения текстовой секции с поддержкой заголовков
  Widget _buildTextSection(String text) {
    final lines = text.split('\n');
    final List<Widget> textWidgets = [];
    
    for (final line in lines) {
      if (line.startsWith('## ')) {
        // Заголовок второго уровня
        textWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.substring(3),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        );
      } else if (line.startsWith('# ')) {
        // Заголовок первого уровня (если используется)
        textWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            child: Text(
              line.substring(2),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
        );
      } else if (line.trim().isEmpty) {
        // Пустая строка - добавляем отступ
        textWidgets.add(const SizedBox(height: 12));
      } else {
        // Обычный текст
        textWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: textWidgets,
    );
  }

  // Метод для построения виджета изображения
  Widget _buildImageWidget(String imagePath) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 250,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 250,
            color: Colors.grey[200],
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('Изображение не найдено', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentWidgets = _parseTipContent(widget.tip.tip, widget.tip.images);

    return CommonScaffold(
      title: widget.tip.name,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Информация о совете
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Уровень ${widget.tip.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.tip.topic,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Основное содержание
              ...contentWidgets,
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}