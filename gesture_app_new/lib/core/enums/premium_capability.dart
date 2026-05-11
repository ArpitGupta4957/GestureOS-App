enum PremiumCapability {
  imageOcr,
  excelImport,
  exportReport,
  manualEntry, // Usually free, kept for completeness
}

extension PremiumCapabilityName on PremiumCapability {
  String get displayName {
    switch (this) {
      case PremiumCapability.imageOcr: return "Image OCR Import";
      case PremiumCapability.excelImport: return "Excel Import";
      case PremiumCapability.exportReport: return "Export Report";
      case PremiumCapability.manualEntry: return "Manual Entry";
    }
  }

  String get key {
    switch (this) {
      case PremiumCapability.imageOcr: return "image_ocr";
      case PremiumCapability.excelImport: return "excel_import";
      case PremiumCapability.exportReport: return "export_report";
      case PremiumCapability.manualEntry: return "manual_entry";
    }
  }

  /// Maps PremiumCapability to backend limit key (e.g., 'max_ocr_scans')
  /// SINGLE SOURCE OF TRUTH for feature-to-limit mapping (Issue #7 fix)
  String get limitKey {
    switch (this) {
      case PremiumCapability.imageOcr:
        return 'max_ocr_scans';
      case PremiumCapability.excelImport:
        return 'max_excel_imports';
      case PremiumCapability.exportReport:
        return 'max_exports';
      case PremiumCapability.manualEntry:
        return 'max_manual_entries';
    }
  }
}
