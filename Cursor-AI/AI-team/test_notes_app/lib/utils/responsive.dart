import 'package:flutter/material.dart';

/// Responsive design utility class for handling different screen sizes.
/// 
/// Provides breakpoints and helper methods for mobile, tablet, and web layouts.
/// Breakpoints are based on Material Design guidelines:
/// - Mobile: < 600px
/// - Tablet: 600px - 1200px
/// - Desktop/Web: >= 1200px
class Responsive {
  /// Mobile breakpoint: screens smaller than 600px
  static const double mobileBreakpoint = 600;
  
  /// Tablet breakpoint: screens between 600px and 1200px
  static const double tabletBreakpoint = 1200;
  
  /// Desktop/Web breakpoint: screens larger than 1200px
  
  /// Returns true if the current screen is mobile-sized
  static bool isMobile(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width < mobileBreakpoint;
  }
  
  /// Returns true if the current screen is tablet-sized
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }
  
  /// Returns true if the current screen is desktop/web-sized
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }
  
  /// Returns true if the device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
  
  /// Returns true if the device is in portrait orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }
  
  /// Returns the current screen type
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }
  
  /// Returns the screen width
  static double getWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  /// Returns the screen height
  static double getHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  /// Returns responsive padding based on screen size
  static EdgeInsets getPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.all(32.0);
    }
  }
  
  /// Returns responsive horizontal padding
  static EdgeInsets getHorizontalPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32.0);
    }
  }
  
  /// Returns responsive vertical padding
  static EdgeInsets getVerticalPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(vertical: 16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(vertical: 24.0);
    } else {
      return const EdgeInsets.symmetric(vertical: 32.0);
    }
  }
  
  /// Returns responsive spacing
  static double getSpacing(BuildContext context) {
    if (isMobile(context)) {
      return 8.0;
    } else if (isTablet(context)) {
      return 12.0;
    } else {
      return 16.0;
    }
  }
  
  /// Returns responsive font size multiplier
  static double getFontSizeMultiplier(BuildContext context) {
    if (isMobile(context)) {
      return 1.0;
    } else if (isTablet(context)) {
      return 1.1;
    } else {
      return 1.2;
    }
  }
  
  /// Returns the number of columns for grid layouts based on screen width
  static int getGridColumns(BuildContext context) {
    final width = getWidth(context);
    if (width < mobileBreakpoint) {
      return 1;
    } else if (width < tabletBreakpoint) {
      // Tablet: 2 columns in portrait, 3 in landscape
      return isLandscape(context) ? 3 : 2;
    } else {
      // Desktop: 3-4 columns based on width
      if (width >= 1600) {
        return 4;
      } else if (width >= 1400) {
        return 3;
      } else {
        return 3;
      }
    }
  }
  
  /// Returns responsive grid column count for a specific max item width
  static int getGridColumnsForItemWidth(BuildContext context, double itemWidth) {
    final availableWidth = getWidth(context) - (getPadding(context).horizontal * 2);
    final columns = (availableWidth / itemWidth).floor();
    return columns.clamp(1, isDesktop(context) ? 4 : (isTablet(context) ? 3 : 1));
  }
  
  /// Returns the maximum width for content containers
  static double getMaxContentWidth(BuildContext context) {
    if (isMobile(context)) {
      return double.infinity;
    } else if (isTablet(context)) {
      return 800;
    } else {
      return 1200;
    }
  }
  
  /// Returns responsive card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(20.0);
    } else {
      return const EdgeInsets.all(24.0);
    }
  }
  
  /// Returns responsive icon size
  static double getIconSize(BuildContext context, {double baseSize = 24.0}) {
    if (isMobile(context)) {
      return baseSize;
    } else if (isTablet(context)) {
      return baseSize * 1.1;
    } else {
      return baseSize * 1.2;
    }
  }
  
  /// Returns responsive dialog width
  static double getDialogWidth(BuildContext context) {
    if (isMobile(context)) {
      return MediaQuery.of(context).size.width * 0.9;
    } else if (isTablet(context)) {
      return 500;
    } else {
      return 600;
    }
  }
  
  /// Returns responsive button padding
  static EdgeInsets getButtonPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0);
    }
  }
  
  /// Returns responsive text field padding
  static EdgeInsets getTextFieldPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);
    }
  }
  
  /// Returns responsive empty state icon size
  static double getEmptyStateIconSize(BuildContext context) {
    if (isMobile(context)) {
      return 64.0;
    } else if (isTablet(context)) {
      return 80.0;
    } else {
      return 96.0;
    }
  }
  
  /// Returns responsive empty state spacing
  static double getEmptyStateSpacing(BuildContext context) {
    if (isMobile(context)) {
      return 16.0;
    } else if (isTablet(context)) {
      return 20.0;
    } else {
      return 24.0;
    }
  }
  
  /// Returns responsive app bar height
  static double getAppBarHeight(BuildContext context) {
    if (isMobile(context)) {
      return kToolbarHeight;
    } else if (isTablet(context)) {
      return kToolbarHeight * 1.1;
    } else {
      return kToolbarHeight * 1.2;
    }
  }
  
  /// Returns responsive FAB size
  static double getFabSize(BuildContext context) {
    if (isMobile(context)) {
      return 56.0;
    } else if (isTablet(context)) {
      return 64.0;
    } else {
      return 64.0;
    }
  }
  
  /// Returns responsive FAB margin
  static EdgeInsets getFabMargin(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.all(32.0);
    }
  }
  
  /// Returns responsive list item height
  static double getListItemHeight(BuildContext context) {
    if (isMobile(context)) {
      return 72.0;
    } else if (isTablet(context)) {
      return 80.0;
    } else {
      return 88.0;
    }
  }
  
  /// Returns responsive card elevation
  static double getCardElevation(BuildContext context) {
    if (isMobile(context)) {
      return 2.0;
    } else if (isTablet(context)) {
      return 3.0;
    } else {
      return 4.0;
    }
  }
  
  /// Returns responsive border radius
  static double getBorderRadius(BuildContext context) {
    if (isMobile(context)) {
      return 12.0;
    } else if (isTablet(context)) {
      return 16.0;
    } else {
      return 20.0;
    }
  }
  
  /// Returns responsive bottom sheet height percentage
  static double getBottomSheetHeight(BuildContext context) {
    if (isMobile(context)) {
      return isLandscape(context) ? 0.6 : 0.7;
    } else if (isTablet(context)) {
      return 0.5;
    } else {
      return 0.4;
    }
  }
  
  /// Returns responsive drawer width
  static double getDrawerWidth(BuildContext context) {
    if (isMobile(context)) {
      return getWidth(context) * 0.85;
    } else if (isTablet(context)) {
      return 320.0;
    } else {
      return 360.0;
    }
  }
  
  /// Returns responsive snackbar margin
  static EdgeInsets getSnackBarMargin(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(
        horizontal: getMaxContentWidth(context) * 0.1,
        vertical: 16.0,
      );
    } else {
      return EdgeInsets.symmetric(
        horizontal: (getWidth(context) - getMaxContentWidth(context)) / 2 + 32.0,
        vertical: 24.0,
      );
    }
  }
  
  /// Returns responsive image size for thumbnails
  static double getThumbnailSize(BuildContext context) {
    if (isMobile(context)) {
      return 48.0;
    } else if (isTablet(context)) {
      return 64.0;
    } else {
      return 80.0;
    }
  }
  
  /// Returns responsive minimum touch target size
  static double getMinTouchTarget(BuildContext context) {
    // Material Design recommends minimum 48x48 touch targets
    if (isMobile(context)) {
      return 48.0;
    } else {
      return 56.0;
    }
  }
  
  /// Returns responsive grid aspect ratio for note cards
  static double getNoteCardAspectRatio(BuildContext context) {
    if (isMobile(context)) {
      return 1.0;
    } else if (isTablet(context)) {
      return isLandscape(context) ? 1.1 : 1.2;
    } else {
      return 1.0;
    }
  }
  
  /// Returns responsive grid aspect ratio for category cards
  static double getCategoryCardAspectRatio(BuildContext context) {
    if (isMobile(context)) {
      return 3.0;
    } else if (isTablet(context)) {
      return isLandscape(context) ? 3.2 : 3.5;
    } else {
      return 4.0;
    }
  }
}

/// Enum representing different screen types
enum ScreenType {
  mobile,
  tablet,
  desktop,
}
