import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  
  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        
        final isPhone = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1200;
        final isDesktop = screenWidth >= 1200;
        
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 12.0 : isTablet ? 20.0 : 32.0,
            vertical: isPhone ? 4.0 : 12.0,
          ),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                maxWidth: isDesktop ? maxWidth! : screenWidth,
              ),
              child: SafeArea(child: child),
            ),
          ),
        );
      },
    );
  }
}

double responsiveWidth(BuildContext context, double mobile, double tablet, double desktop) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 1200) return desktop;
  if (width >= 600) return tablet;
  return mobile;
}

double responsiveHeight(BuildContext context, double mobile, double tablet, double desktop) {
  final height = MediaQuery.of(context).size.height;
  if (height >= 900) return desktop;
  if (height >= 600) return tablet;
  return mobile;
}

double responsiveFontSize(BuildContext context, double mobile, double tablet, double desktop) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 1200) return desktop;
  if (width >= 600) return tablet;
  return mobile;
}

// ✅ Экспорт для удобства
class Responsive {
  static double width(BuildContext context, double mobile, double tablet, double desktop) => 
      responsiveWidth(context, mobile, tablet, desktop);
  static double height(BuildContext context, double mobile, double tablet, double desktop) => 
      responsiveHeight(context, mobile, tablet, desktop);
  static double font(BuildContext context, double mobile, double tablet, double desktop) => 
      responsiveFontSize(context, mobile, tablet, desktop);
}
