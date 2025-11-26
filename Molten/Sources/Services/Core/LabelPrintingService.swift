//
//  LabelPrintingService.swift
//  Molten
//
//  Service for generating printable labels with QR codes for inventory items
//

#if os(iOS)
import UIKit
#endif
import CoreImage.CIFilterBuiltins
import Combine

/// Avery label format specifications
///
/// Data sources for template specifications:
/// - Primary: CSV database from https://gist.github.com/armadsen/5084458
/// - Secondary: XML templates from https://github.com/yardstick/PDF-Labels
/// - Verification: Official Avery product specifications
///
/// All dimensions in points (1 point = 1/72 inch)
/// Standard sheet size: 8.5" × 11" (US Letter) = 612 × 792 points
struct AveryFormat: Equatable, Hashable {
    let name: String
    let labelsPerSheet: Int
    let columns: Int
    let rows: Int
    let labelWidth: CGFloat  // in points (1/72 inch)
    let labelHeight: CGFloat
    let leftMargin: CGFloat
    let topMargin: CGFloat
    let horizontalGap: CGFloat
    let verticalGap: CGFloat

    // Default formatting for this label size
    let defaultFontScale: CGFloat
    let defaultQRSize: CGFloat  // as percentage of label height (0.5 to 0.8)

    /// Avery 5160 (Address Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    /// Most common format for rod labels
    static let avery5160 = AveryFormat(
        name: "Avery 5160",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189,  // 2.625" × 72 = 189pt
        labelHeight: 72,  // 1" × 72 = 72pt
        leftMargin: 13.5,  // 0.1875" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 9,  // Spacing: 2.75" × 72 - 189pt = 9pt
        verticalGap: 0,  // Labels are vertically contiguous
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5163 (Shipping Labels)
    /// 10 labels per sheet (2 columns × 5 rows)
    /// 2" × 4" per label
    /// Use for box labels with more detailed info
    static let avery5163 = AveryFormat(
        name: "Avery 5163",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 288,  // 4" × 72 = 288pt
        labelHeight: 144,  // 2" × 72 = 144pt
        leftMargin: 18,
        topMargin: 36,
        horizontalGap: 18,
        verticalGap: 0,
        defaultFontScale: 1.2,  // Larger label = can afford bigger text
        defaultQRSize: 0.6
    )

    /// Avery 5167 (Return Address)
    /// 80 labels per sheet (4 columns × 20 rows)
    /// ½" × 1¾" per label
    /// Use for tiny labels on small rods
    static let avery5167 = AveryFormat(
        name: "Avery 5167",
        labelsPerSheet: 80,
        columns: 4,
        rows: 20,
        labelWidth: 126,  // 1¾" × 72 = 126pt
        labelHeight: 36,  // ½" × 72 = 36pt
        leftMargin: 20.25,  // 0.28125" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 22.5,  // Spacing: 2.0625" × 72 - 126pt = 22.5pt
        verticalGap: 0,  // Labels are vertically contiguous
        defaultFontScale: 0.75,  // Tiny label = need smaller text
        defaultQRSize: 0.7
    )

    /// Avery 18167 (Return Address - Same dimensions as 5167)
    /// 80 labels per sheet (4 columns × 20 rows)
    /// ½" × 1¾" per label
    /// Alternative product code for same format as 5167
    static let avery18167 = AveryFormat(
        name: "Avery 18167",
        labelsPerSheet: 80,
        columns: 4,
        rows: 20,
        labelWidth: 126,  // 1¾" × 72 = 126pt
        labelHeight: 36,  // ½" × 72 = 36pt
        leftMargin: 20.25,  // 0.28125" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 22.5,  // Spacing: 2.0625" × 72 - 126pt = 22.5pt
        verticalGap: 0,  // Labels are vertically contiguous
        defaultFontScale: 0.75,  // Tiny label = need smaller text
        defaultQRSize: 0.7
    )

    /// Mr-Label MR184 (Cable Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2.625" per label (similar layout to Avery 5160)
    /// Waterproof, tear-resistant flag-style cable labels
    /// Note: Use offset adjustments in UI to fine-tune alignment for your specific label sheets
    static let mrLabel184 = AveryFormat(
        name: "Mr-Label MR184",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189,  // 2.625" × 72 = 189pt (same as Avery 5160)
        labelHeight: 72,  // 1" × 72 = 72pt
        leftMargin: 13.5,  // 0.1875" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 9,  // Spacing between columns
        verticalGap: 0,  // Labels are vertically contiguous
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Additional Address Labels

    /// Avery 5161 (Address Labels)
    /// 20 labels per sheet (2 columns × 10 rows)
    /// 1" × 4" per label
    /// Larger width than 5160, good for longer text
    static let avery5161 = AveryFormat(
        name: "Avery 5161",
        labelsPerSheet: 20,
        columns: 2,
        rows: 10,
        labelWidth: 288,  // 4" × 72
        labelHeight: 72,  // 1" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5162 (Address Labels)
    /// 14 labels per sheet (2 columns × 7 rows)
    /// 1.33" × 4" per label
    /// Taller labels for more text per label
    static let avery5162 = AveryFormat(
        name: "Avery 5162",
        labelsPerSheet: 14,
        columns: 2,
        rows: 7,
        labelWidth: 288,  // 4" × 72
        labelHeight: 96,  // 1.33" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 60,  // 0.833" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5164 (Shipping Labels)
    /// 6 labels per sheet (2 columns × 3 rows)
    /// 3.33" × 4" per label
    /// Large labels for detailed shipping information
    static let avery5164 = AveryFormat(
        name: "Avery 5164",
        labelsPerSheet: 6,
        columns: 2,
        rows: 3,
        labelWidth: 288,  // 4" × 72
        labelHeight: 240,  // 3.33" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5159 (Address Labels)
    /// 14 labels per sheet (2 columns × 7 rows)
    /// 1.25" × 4" per label
    /// Similar to 5162 but slightly smaller height
    static let avery5159 = AveryFormat(
        name: "Avery 5159",
        labelsPerSheet: 14,
        columns: 2,
        rows: 7,
        labelWidth: 288,  // 4" × 72
        labelHeight: 90,  // 1.25" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 18,  // 0.25" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Small Labels (High Density)

    /// Avery 5260 (Address Labels - Same as 5160)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    /// EasyPeel version of 5160
    static let avery5260 = AveryFormat(
        name: "Avery 5260",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189,  // 2.625" × 72
        labelHeight: 72,  // 1" × 72
        leftMargin: 13.5,  // 0.188" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 9,  // 0.125" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5261 (Address Labels - Same as 5161)
    /// 20 labels per sheet (2 columns × 10 rows)
    /// 1" × 4" per label
    /// EasyPeel version of 5161
    static let avery5261 = AveryFormat(
        name: "Avery 5261",
        labelsPerSheet: 20,
        columns: 2,
        rows: 10,
        labelWidth: 288,  // 4" × 72
        labelHeight: 72,  // 1" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5262 (Address Labels - Same as 5162)
    /// 14 labels per sheet (2 columns × 7 rows)
    /// 1.33" × 4" per label
    /// EasyPeel version of 5162
    static let avery5262 = AveryFormat(
        name: "Avery 5262",
        labelsPerSheet: 14,
        columns: 2,
        rows: 7,
        labelWidth: 288,  // 4" × 72
        labelHeight: 96,  // 1.33" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 60,  // 0.835" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5263 (Shipping Labels - Same as 5163)
    /// 10 labels per sheet (2 columns × 5 rows)
    /// 2" × 4" per label
    /// EasyPeel version of 5163
    static let avery5263 = AveryFormat(
        name: "Avery 5263",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 288,  // 4" × 72
        labelHeight: 144,  // 2" × 72
        leftMargin: 12.25,  // 0.17" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 11.5,  // 0.16" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5264 (Shipping Labels - Same as 5164)
    /// 6 labels per sheet (2 columns × 3 rows)
    /// 3.33" × 4" per label
    /// EasyPeel version of 5164
    static let avery5264 = AveryFormat(
        name: "Avery 5264",
        labelsPerSheet: 6,
        columns: 2,
        rows: 3,
        labelWidth: 288,  // 4" × 72
        labelHeight: 240,  // 3.33" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5267 (Return Address - Same as 5167)
    /// 80 labels per sheet (4 columns × 20 rows)
    /// ½" × 1¾" per label
    /// EasyPeel version of 5167
    static let avery5267 = AveryFormat(
        name: "Avery 5267",
        labelsPerSheet: 80,
        columns: 4,
        rows: 20,
        labelWidth: 126,  // 1.75" × 72
        labelHeight: 36,  // 0.5" × 72
        leftMargin: 21.6,  // 0.3" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 21.6,  // 0.3" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Inkjet Labels (8xxx Series)

    /// Avery 8160 (Address Labels - Inkjet)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    /// Inkjet version of 5160
    static let avery8160 = AveryFormat(
        name: "Avery 8160",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189,  // 2.625" × 72
        labelHeight: 72,  // 1" × 72
        leftMargin: 13.5,  // 0.188" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 9,  // 0.125" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8161 (Address Labels - Inkjet)
    /// 20 labels per sheet (2 columns × 10 rows)
    /// 1" × 4" per label
    /// Inkjet version of 5161
    static let avery8161 = AveryFormat(
        name: "Avery 8161",
        labelsPerSheet: 20,
        columns: 2,
        rows: 10,
        labelWidth: 288,  // 4" × 72
        labelHeight: 72,  // 1" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8162 (Address Labels - Inkjet)
    /// 14 labels per sheet (2 columns × 7 rows)
    /// 1.33" × 4" per label
    /// Inkjet version of 5162
    static let avery8162 = AveryFormat(
        name: "Avery 8162",
        labelsPerSheet: 14,
        columns: 2,
        rows: 7,
        labelWidth: 288,  // 4" × 72
        labelHeight: 96,  // 1.33" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 60,  // 0.833" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8163 (Shipping Labels - Inkjet)
    /// 10 labels per sheet (2 columns × 5 rows)
    /// 2" × 4" per label
    /// Inkjet version of 5163
    static let avery8163 = AveryFormat(
        name: "Avery 8163",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 288,  // 4" × 72
        labelHeight: 144,  // 2" × 72
        leftMargin: 12.25,  // 0.17" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 11.5,  // 0.16" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8164 (Shipping Labels - Inkjet)
    /// 6 labels per sheet (2 columns × 3 rows)
    /// 3.33" × 4" per label
    /// Inkjet version of 5164
    static let avery8164 = AveryFormat(
        name: "Avery 8164",
        labelsPerSheet: 6,
        columns: 2,
        rows: 3,
        labelWidth: 288,  // 4" × 72
        labelHeight: 240,  // 3.33" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8167 (Return Address - Inkjet)
    /// 80 labels per sheet (4 columns × 20 rows)
    /// ½" × 1¾" per label
    /// Inkjet version of 5167
    static let avery8167 = AveryFormat(
        name: "Avery 8167",
        labelsPerSheet: 80,
        columns: 4,
        rows: 20,
        labelWidth: 126,  // 1.75" × 72
        labelHeight: 36,  // 0.5" × 72
        leftMargin: 21.6,  // 0.3" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 21.6,  // 0.3" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Specialty Labels

    /// Avery 5168 (Shipping Labels)
    /// 4 labels per sheet (2 columns × 2 rows)
    /// 3.5" × 5" per label
    /// Extra large labels for packages
    static let avery5168 = AveryFormat(
        name: "Avery 5168",
        labelsPerSheet: 4,
        columns: 2,
        rows: 2,
        labelWidth: 360,  // 5" × 72
        labelHeight: 252,  // 3.5" × 72
        leftMargin: 36,  // 0.5" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 36,  // 0.5" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5960 (Address Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    /// Template-free edge labels (same as 5160)
    static let avery5960 = AveryFormat(
        name: "Avery 5960",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189,  // 2.625" × 72
        labelHeight: 72,  // 1" × 72
        leftMargin: 13.5,  // 0.188" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 9,  // 0.125" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5961 (Address Labels)
    /// 20 labels per sheet (2 columns × 10 rows)
    /// 1" × 4" per label
    /// Template-free edge labels (same as 5161)
    static let avery5961 = AveryFormat(
        name: "Avery 5961",
        labelsPerSheet: 20,
        columns: 2,
        rows: 10,
        labelWidth: 288,  // 4" × 72
        labelHeight: 72,  // 1" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5962 (Address Labels)
    /// 14 labels per sheet (2 columns × 7 rows)
    /// 1.33" × 4" per label
    /// Template-free edge labels (same as 5162)
    static let avery5962 = AveryFormat(
        name: "Avery 5962",
        labelsPerSheet: 14,
        columns: 2,
        rows: 7,
        labelWidth: 288,  // 4" × 72
        labelHeight: 96,  // 1.33" × 72
        leftMargin: 11.25,  // 0.156" × 72
        topMargin: 60,  // 0.833" × 72
        horizontalGap: 13.5,  // 0.188" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5963 (Shipping Labels)
    /// 10 labels per sheet (2 columns × 5 rows)
    /// 2" × 4" per label
    /// Template-free edge labels (same as 5163)
    static let avery5963 = AveryFormat(
        name: "Avery 5963",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 288,  // 4" × 72
        labelHeight: 144,  // 2" × 72
        leftMargin: 12.25,  // 0.17" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 11.5,  // 0.16" × 72
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Name Badge Labels

    /// Avery 5395 (Name Badge Labels)
    /// 8 labels per sheet (2 columns × 4 rows)
    /// 2⅓" × 3⅜" per label
    /// Perfect for name tags and badges
    static let avery5395 = AveryFormat(
        name: "Avery 5395",
        labelsPerSheet: 8,
        columns: 2,
        rows: 4,
        labelWidth: 243,  // 3.375" × 72
        labelHeight: 168,  // 2.33" × 72
        leftMargin: 27,  // 0.375" × 72
        topMargin: 45,  // 0.625" × 72
        horizontalGap: 18,  // 0.25" × 72
        verticalGap: 18,  // 0.25" × 72
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 6870 (Durable ID Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// ¾" × 2¼" per label
    /// Smaller than 5160, good for asset tags
    static let avery6870 = AveryFormat(
        name: "Avery 6870",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 162,  // 2.25" × 72
        labelHeight: 54,  // 0.75" × 72
        leftMargin: 27,  // 0.375" × 72
        topMargin: 45,  // 0.625" × 72
        horizontalGap: 36,  // 0.5" × 72
        verticalGap: 18,  // 0.25" × 72
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8371 (Business Cards)
    /// 10 per sheet (2 columns × 5 rows)
    /// 2" × 3.5" per label
    /// Standard business card size
    static let avery8371 = AveryFormat(
        name: "Avery 8371",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 252,  // 3.5" × 72
        labelHeight: 144,  // 2" × 72
        leftMargin: 27,  // Calculated from sheet width
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 0,
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5165 (Full Sheet Labels)
    /// 1 label per sheet
    /// 8.5" × 11" full page
    /// For posters, signs, or full-page designs
    static let avery5165 = AveryFormat(
        name: "Avery 5165",
        labelsPerSheet: 1,
        columns: 1,
        rows: 1,
        labelWidth: 612,  // 8.5" × 72
        labelHeight: 792,  // 11" × 72
        leftMargin: 0,
        topMargin: 0,
        horizontalGap: 0,
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8165 (Full Sheet Labels - Inkjet)
    /// 1 label per sheet
    /// 8.5" × 11" full page
    /// Inkjet version for posters, signs, or full-page designs
    static let avery8165 = AveryFormat(
        name: "Avery 8165",
        labelsPerSheet: 1,
        columns: 1,
        rows: 1,
        labelWidth: 612,  // 8.5" × 72
        labelHeight: 792,  // 11" × 72
        leftMargin: 0,
        topMargin: 0,
        horizontalGap: 0,
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Laser Labels (55xx Series)

    /// Avery 5510 (Laser Address Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    static let avery5510 = AveryFormat(
        name: "Avery 5510",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189.0,
        labelHeight: 72.0,
        leftMargin: 13.54,
        topMargin: 36.00,
        horizontalGap: 9.00,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5512 (Laser Address Labels)
    /// 14 labels per sheet (2 columns × 7 rows)
    /// 1⅓" × 4" per label
    static let avery5512 = AveryFormat(
        name: "Avery 5512",
        labelsPerSheet: 14,
        columns: 2,
        rows: 7,
        labelWidth: 288.0,
        labelHeight: 96.0,
        leftMargin: 11.23,
        topMargin: 59.98,
        horizontalGap: 13.54,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5513 (Laser Shipping Labels)
    /// 10 labels per sheet (2 columns × 5 rows)
    /// 2" × 4" per label
    static let avery5513 = AveryFormat(
        name: "Avery 5513",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 288.0,
        labelHeight: 144.0,
        leftMargin: 12.24,
        topMargin: 36.00,
        horizontalGap: 11.52,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5514 (Laser Shipping Labels)
    /// 6 labels per sheet (2 columns × 3 rows)
    /// 3⅓" × 4" per label
    static let avery5514 = AveryFormat(
        name: "Avery 5514",
        labelsPerSheet: 6,
        columns: 2,
        rows: 3,
        labelWidth: 288.0,
        labelHeight: 240.0,
        leftMargin: 11.23,
        topMargin: 36.00,
        horizontalGap: 13.54,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5516 (Laser Half Sheet Labels)
    /// 2 labels per sheet (1 column × 2 rows)
    /// 5.5" × 8.5" per label
    static let avery5516 = AveryFormat(
        name: "Avery 5516",
        labelsPerSheet: 2,
        columns: 1,
        rows: 2,
        labelWidth: 606.2,
        labelHeight: 393.1,
        leftMargin: 2.88,
        topMargin: 2.88,
        horizontalGap: 0.00,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5520 (Laser Address Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    static let avery5520 = AveryFormat(
        name: "Avery 5520",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189.0,
        labelHeight: 72.0,
        leftMargin: 13.54,
        topMargin: 36.00,
        horizontalGap: 9.00,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5522 (Laser Address Labels)
    /// 14 labels per sheet (2 columns × 7 rows)
    /// 1⅓" × 4" per label
    static let avery5522 = AveryFormat(
        name: "Avery 5522",
        labelsPerSheet: 14,
        columns: 2,
        rows: 7,
        labelWidth: 288.0,
        labelHeight: 96.0,
        leftMargin: 11.23,
        topMargin: 59.98,
        horizontalGap: 13.54,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5523 (Laser Shipping Labels)
    /// 10 labels per sheet (2 columns × 5 rows)
    /// 2" × 4" per label
    static let avery5523 = AveryFormat(
        name: "Avery 5523",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 288.0,
        labelHeight: 144.0,
        leftMargin: 12.24,
        topMargin: 36.00,
        horizontalGap: 11.52,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5524 (Laser Shipping Labels)
    /// 6 labels per sheet (2 columns × 3 rows)
    /// 3⅓" × 4" per label
    static let avery5524 = AveryFormat(
        name: "Avery 5524",
        labelsPerSheet: 6,
        columns: 2,
        rows: 3,
        labelWidth: 288.0,
        labelHeight: 240.0,
        leftMargin: 11.23,
        topMargin: 36.00,
        horizontalGap: 13.54,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5526 (Laser Shipping Labels)
    /// 8 labels per sheet (2 columns × 4 rows)
    /// 2" × 4" per label
    static let avery5526 = AveryFormat(
        name: "Avery 5526",
        labelsPerSheet: 8,
        columns: 2,
        rows: 4,
        labelWidth: 288.0,
        labelHeight: 144.0,
        leftMargin: 18.00,
        topMargin: 36.00,
        horizontalGap: 18.00,
        verticalGap: 36.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5560 (Laser Mailing Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    static let avery5560 = AveryFormat(
        name: "Avery 5560",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189.0,
        labelHeight: 72.0,
        leftMargin: 13.54,
        topMargin: 36.00,
        horizontalGap: 9.00,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Round/Circle Labels

    /// Avery 5293 (Round Labels)
    /// 12 labels per sheet (3 columns × 4 rows)
    /// 2.5" diameter circles
    static let avery5293 = AveryFormat(
        name: "Avery 5293",
        labelsPerSheet: 12,
        columns: 3,
        rows: 4,
        labelWidth: 180.0,  // 2.5" diameter
        labelHeight: 180.0,
        leftMargin: 41.04,
        topMargin: 54.00,
        horizontalGap: 18.00,
        verticalGap: 18.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5294 (Round Labels)
    /// 32 labels per sheet (4 columns × 8 rows)
    /// 1.5" diameter circles
    static let avery5294 = AveryFormat(
        name: "Avery 5294",
        labelsPerSheet: 32,
        columns: 4,
        rows: 8,
        labelWidth: 108.0,  // 1.5" diameter
        labelHeight: 108.0,
        leftMargin: 36.00,
        topMargin: 18.00,
        horizontalGap: 18.00,
        verticalGap: 18.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5923 (Round Labels)
    /// 12 labels per sheet (3 columns × 4 rows)
    /// 2.5" diameter circles
    static let avery5923 = AveryFormat(
        name: "Avery 5923",
        labelsPerSheet: 12,
        columns: 3,
        rows: 4,
        labelWidth: 180.0,  // 2.5" diameter
        labelHeight: 180.0,
        leftMargin: 41.04,
        topMargin: 54.00,
        horizontalGap: 18.00,
        verticalGap: 18.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5930 (Round Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1.5" diameter circles
    static let avery5930 = AveryFormat(
        name: "Avery 5930",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 108.0,  // 1.5" diameter
        labelHeight: 108.0,
        leftMargin: 54.00,
        topMargin: 27.00,
        horizontalGap: 27.00,
        verticalGap: 9.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - File Folder Labels

    /// Avery 5734 (File Folder Labels)
    /// 78 labels per sheet (6 columns × 13 rows)
    /// ⅔" × 3.44" per label
    static let avery5734 = AveryFormat(
        name: "Avery 5734",
        labelsPerSheet: 78,
        columns: 6,
        rows: 13,
        labelWidth: 247.7,
        labelHeight: 48.0,
        leftMargin: 11.23,
        topMargin: 18.00,
        horizontalGap: 0.00,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 5777 (File Folder Labels)
    /// 78 labels per sheet (6 columns × 13 rows)
    /// ⅔" × 3.44" per label
    static let avery5777 = AveryFormat(
        name: "Avery 5777",
        labelsPerSheet: 78,
        columns: 6,
        rows: 13,
        labelWidth: 247.7,
        labelHeight: 48.0,
        leftMargin: 11.23,
        topMargin: 18.00,
        horizontalGap: 0.00,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Durable/Ultra Duty Labels

    /// Avery 6871 (Durable ID Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// ¾" × 2.25" per label
    static let avery6871 = AveryFormat(
        name: "Avery 6871",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 162.0,
        labelHeight: 54.0,
        leftMargin: 27.00,
        topMargin: 45.00,
        horizontalGap: 36.00,
        verticalGap: 18.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 6873 (Ultra Duty Labels)
    /// 20 labels per sheet (4 columns × 5 rows)
    /// 1.25" × 1.75" per label
    static let avery6873 = AveryFormat(
        name: "Avery 6873",
        labelsPerSheet: 20,
        columns: 4,
        rows: 5,
        labelWidth: 126.0,
        labelHeight: 90.0,
        leftMargin: 27.00,
        topMargin: 54.00,
        horizontalGap: 27.00,
        verticalGap: 27.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 6874 (Ultra Duty Labels)
    /// 8 labels per sheet (2 columns × 4 rows)
    /// 2.33" × 3.375" per label
    static let avery6874 = AveryFormat(
        name: "Avery 6874",
        labelsPerSheet: 8,
        columns: 2,
        rows: 4,
        labelWidth: 243.0,
        labelHeight: 168.0,
        leftMargin: 27.00,
        topMargin: 45.00,
        horizontalGap: 18.00,
        verticalGap: 18.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Additional Inkjet Labels (82xx, 84xx, 86xx, 87xx)

    /// Avery 8250 (Inkjet Address Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    static let avery8250 = AveryFormat(
        name: "Avery 8250",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189.0,
        labelHeight: 72.0,
        leftMargin: 13.54,
        topMargin: 36.00,
        horizontalGap: 9.00,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8253 (Inkjet Shipping Labels)
    /// 10 labels per sheet (2 columns × 5 rows)
    /// 2" × 4" per label
    static let avery8253 = AveryFormat(
        name: "Avery 8253",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 288.0,
        labelHeight: 144.0,
        leftMargin: 12.24,
        topMargin: 36.00,
        horizontalGap: 11.52,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8460 (Inkjet Address Labels)
    /// 20 labels per sheet (2 columns × 10 rows)
    /// 1" × 4" per label
    static let avery8460 = AveryFormat(
        name: "Avery 8460",
        labelsPerSheet: 20,
        columns: 2,
        rows: 10,
        labelWidth: 288.0,
        labelHeight: 72.0,
        leftMargin: 11.23,
        topMargin: 36.00,
        horizontalGap: 13.54,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8461 (Inkjet Address Labels)
    /// 20 labels per sheet (2 columns × 10 rows)
    /// 1" × 4" per label
    static let avery8461 = AveryFormat(
        name: "Avery 8461",
        labelsPerSheet: 20,
        columns: 2,
        rows: 10,
        labelWidth: 288.0,
        labelHeight: 72.0,
        leftMargin: 11.23,
        topMargin: 36.00,
        horizontalGap: 13.54,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8462 (Inkjet Address Labels)
    /// 14 labels per sheet (2 columns × 7 rows)
    /// 1⅓" × 4" per label
    static let avery8462 = AveryFormat(
        name: "Avery 8462",
        labelsPerSheet: 14,
        columns: 2,
        rows: 7,
        labelWidth: 288.0,
        labelHeight: 96.0,
        leftMargin: 11.23,
        topMargin: 59.98,
        horizontalGap: 13.54,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8660 (Inkjet Address Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    static let avery8660 = AveryFormat(
        name: "Avery 8660",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189.0,
        labelHeight: 72.0,
        leftMargin: 13.54,
        topMargin: 36.00,
        horizontalGap: 9.00,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 8760 (Inkjet Address Labels)
    /// 20 labels per sheet (2 columns × 10 rows)
    /// 1" × 4" per label
    static let avery8760 = AveryFormat(
        name: "Avery 8760",
        labelsPerSheet: 20,
        columns: 2,
        rows: 10,
        labelWidth: 288.0,
        labelHeight: 72.0,
        leftMargin: 11.23,
        topMargin: 36.00,
        horizontalGap: 13.54,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - Multipurpose Labels

    /// Avery 5810 (Multipurpose Labels)
    /// 42 labels per sheet (3 columns × 14 rows)
    /// ½" × 1.75" per label
    static let avery5810 = AveryFormat(
        name: "Avery 5810",
        labelsPerSheet: 42,
        columns: 3,
        rows: 14,
        labelWidth: 126.0,
        labelHeight: 36.0,
        leftMargin: 54.00,
        topMargin: 40.50,
        horizontalGap: 54.00,
        verticalGap: 0.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    /// Avery 6464 (Multipurpose Labels)
    /// 24 labels per sheet (3 columns × 8 rows)
    /// 1⅓" × 2.33" per label
    static let avery6464 = AveryFormat(
        name: "Avery 6464",
        labelsPerSheet: 24,
        columns: 3,
        rows: 8,
        labelWidth: 168.0,
        labelHeight: 96.0,
        leftMargin: 27.00,
        topMargin: 54.00,
        horizontalGap: 27.00,
        verticalGap: 27.00,
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )

    // MARK: - All Available Formats

    /// All available Avery formats, organized by category
    static let allFormats: [String: [AveryFormat]] = [
        "Popular": [
            .avery5160,
            .avery5163,
            .avery5167,
            .avery8160,
            .avery8163,
            .avery8167
        ],
        "Address Labels": [
            .avery5160,
            .avery5161,
            .avery5162,
            .avery5159,
            .avery5260,
            .avery5261,
            .avery5262,
            .avery5960,
            .avery5961,
            .avery5962,
            .avery5510,
            .avery5512,
            .avery5520,
            .avery5522,
            .avery5560,
            .avery8460,
            .avery8461,
            .avery8462,
            .avery8660,
            .avery8760,
            .avery8250
        ],
        "Shipping Labels": [
            .avery5163,
            .avery5164,
            .avery5168,
            .avery5263,
            .avery5264,
            .avery5963,
            .avery5513,
            .avery5514,
            .avery5516,
            .avery5523,
            .avery5524,
            .avery5526,
            .avery8253
        ],
        "Return Address": [
            .avery5167,
            .avery18167,
            .avery5267,
            .avery8167
        ],
        "Round/Circle Labels": [
            .avery5293,
            .avery5294,
            .avery5923,
            .avery5930
        ],
        "File Folder Labels": [
            .avery5734,
            .avery5777
        ],
        "Durable/Ultra Duty": [
            .avery6870,
            .avery6871,
            .avery6873,
            .avery6874
        ],
        "Multipurpose": [
            .avery5810,
            .avery6464
        ],
        "Name Badges & Cards": [
            .avery5395,
            .avery8371
        ],
        "Full Sheet": [
            .avery5165,
            .avery8165
        ],
        "Other Brands": [
            .mrLabel184
        ]
    ]

    /// Get a flat list of all formats
    static var flatList: [AveryFormat] {
        var seen = Set<String>()
        var result: [AveryFormat] = []

        for category in allFormats.values {
            for format in category {
                if !seen.contains(format.name) {
                    seen.insert(format.name)
                    result.append(format)
                }
            }
        }

        return result.sorted { $0.name < $1.name }
    }
}

/// QR code position on label
enum QRCodePosition: String, CaseIterable, Codable {
    case none = "None"
    case left = "Left side"
    case right = "Right side"
    case both = "Both sides"
}

/// Manufacturer image position on label
enum ManufacturerImagePosition: String, CaseIterable, Codable {
    case none = "None"
    case left = "Left side"
    case right = "Right side"
    case both = "Both sides"
}

/// Text alignment on label
enum LabelTextAlignment: String, CaseIterable, Codable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
}

/// Text field that can be included on a label
enum LabelTextField: String, CaseIterable, Codable {
    case manufacturer = "Manufacturer"
    case sku = "SKU"
    case colorName = "Color Name"
    case coe = "COE"
    case location = "Location"
    case owner = "Owner"

    var estimatedHeight: CGFloat {
        switch self {
        case .manufacturer, .sku: return 10  // Bold font, slightly taller
        case .colorName: return 9
        case .coe, .location, .owner: return 8
        }
    }
}

/// Formatting configuration for individual label fields
struct LabelFieldFormat: Equatable, Codable {
    var fontSize: CGFloat
    var bold: Bool
    var italic: Bool

    /// Default formats for each field type
    static let defaults: [LabelTextField: LabelFieldFormat] = [
        .manufacturer: LabelFieldFormat(fontSize: 9, bold: true, italic: false),
        .sku: LabelFieldFormat(fontSize: 9, bold: true, italic: false),
        .colorName: LabelFieldFormat(fontSize: 8, bold: false, italic: false),
        .coe: LabelFieldFormat(fontSize: 7, bold: false, italic: false),
        .location: LabelFieldFormat(fontSize: 7, bold: false, italic: false),
        .owner: LabelFieldFormat(fontSize: 7, bold: false, italic: false)
    ]

    /// Get default format for a field
    static func defaultFormat(for field: LabelTextField) -> LabelFieldFormat {
        return defaults[field] ?? LabelFieldFormat(fontSize: 8, bold: false, italic: false)
    }
}

/// Label builder configuration - user-customizable label layout
struct LabelBuilderConfig: Equatable, Codable {
    var qrPosition: QRCodePosition
    var qrSize: CGFloat?  // as percentage of label height (0.5 to 0.8) - nil = use format default
    var fontScale: CGFloat?  // text size multiplier - nil = use format default
    var manufacturerImagePosition: ManufacturerImagePosition
    var manufacturerImageSize: CGFloat?  // as percentage of label height - nil = use default (0.6)
    var textFields: [LabelTextField]
    var textAlignment: LabelTextAlignment  // text alignment (left, center, right)
    var fieldFormats: [LabelTextField: LabelFieldFormat]  // per-field formatting

    /// Default configuration (information dense)
    static let `default` = LabelBuilderConfig(
        qrPosition: .left,
        qrSize: nil,  // Use format default
        fontScale: nil,  // Use format default
        manufacturerImagePosition: .right,  // Add manufacturer logo on right
        manufacturerImageSize: nil,  // Use default (0.6)
        textFields: [.manufacturer, .sku, .colorName, .coe],
        textAlignment: .left,
        fieldFormats: [:]  // Empty - use LabelFieldFormat.defaults
    )

    /// Get format for a specific field (with fallback to default)
    func format(for field: LabelTextField) -> LabelFieldFormat {
        return fieldFormats[field] ?? LabelFieldFormat.defaultFormat(for: field)
    }

    /// Check if manufacturer image overlaps with QR code
    func manufacturerImageOverlapsQR() -> Bool {
        guard manufacturerImagePosition != .none else { return false }

        // Check for overlaps
        switch (qrPosition, manufacturerImagePosition) {
        case (.left, .left), (.right, .right):
            return true  // Same side = overlap
        case (.both, _), (_, .both):
            return true  // Either QR or image on both sides = always overlaps
        default:
            return false
        }
    }

    /// Preset configurations for common use cases
    static let presets: [LabelBuilderPreset] = [
        LabelBuilderPreset(
            name: "Information Dense",
            description: "Maximum info with QR code on left",
            config: LabelBuilderConfig(
                qrPosition: .left,
                qrSize: nil,  // Use format default
                fontScale: nil,  // Use format default
                manufacturerImagePosition: .right,  // Add manufacturer logo on right
                manufacturerImageSize: nil,  // Use default (0.6)
                textFields: [.manufacturer, .sku, .colorName, .coe],
                textAlignment: .left,
                fieldFormats: [:]  // Empty - use LabelFieldFormat.defaults
            )
        ),
        LabelBuilderPreset(
            name: "QR Focused",
            description: "Large QR code, minimal text",
            config: LabelBuilderConfig(
                qrPosition: .left,
                qrSize: nil,  // Use format default
                fontScale: nil,  // Use format default
                manufacturerImagePosition: .none,
                manufacturerImageSize: nil,
                textFields: [.manufacturer, .sku],
                textAlignment: .left,
                fieldFormats: [:]  // Empty - use LabelFieldFormat.defaults
            )
        ),
        LabelBuilderPreset(
            name: "Dual QR",
            description: "QR codes on both ends",
            config: LabelBuilderConfig(
                qrPosition: .both,
                qrSize: nil,  // Use format default
                fontScale: nil,  // Use format default
                manufacturerImagePosition: .none,
                manufacturerImageSize: nil,
                textFields: [.manufacturer, .sku, .colorName],
                textAlignment: .center,
                fieldFormats: [:]  // Empty - use LabelFieldFormat.defaults
            )
        ),
        LabelBuilderPreset(
            name: "Location Labels",
            description: "With location information",
            config: LabelBuilderConfig(
                qrPosition: .left,
                qrSize: nil,  // Use format default
                fontScale: nil,  // Use format default
                manufacturerImagePosition: .none,
                manufacturerImageSize: nil,
                textFields: [.manufacturer, .sku, .colorName, .location],  // Removed .coe
                textAlignment: .left,
                fieldFormats: [:]  // Empty - use LabelFieldFormat.defaults
            )
        )
    ]

    /// Convert to legacy LabelTemplate for backwards compatibility
    func toLegacyTemplate(format: AveryFormat) -> LabelTemplate {
        return LabelTemplate(
            name: "Custom",
            includeQRCode: qrPosition != .none,
            dualQRCodes: qrPosition == .both,
            includeManufacturer: textFields.contains(.manufacturer),
            includeSKU: textFields.contains(.sku),
            includeColor: textFields.contains(.colorName),
            includeCOE: textFields.contains(.coe),
            includeQuantity: false,  // Not used in builder config
            includeLocation: textFields.contains(.location),
            includeOwner: textFields.contains(.owner),
            qrCodeSize: qrSize ?? format.defaultQRSize
        )
    }

    /// Estimate if content will fit within label bounds
    /// - Parameters:
    ///   - format: The Avery format to check against
    ///   - fontScale: Font scale multiplier
    /// - Returns: (fits, estimatedHeight, warnings)
    /// - Note: QR codes will NEVER overflow - they are sized to always fit. Only text may be truncated.
    func validateLayout(for format: AveryFormat, fontScale: CGFloat = 1.0) -> LabelLayoutValidation {
        let padding: CGFloat = 4
        var warnings: [String] = []

        // Calculate available text area
        var availableWidth = format.labelWidth - (padding * 2)
        let availableHeight = format.labelHeight - (padding * 2)

        // Account for QR code(s) - QR codes are sized as percentage of label height, so they always fit
        if qrPosition != .none {
            let effectiveQRSize = qrSize ?? format.defaultQRSize
            let qrSize = format.labelHeight * effectiveQRSize

            switch qrPosition {
            case .left, .right:
                availableWidth -= (qrSize + padding)
            case .both:
                availableWidth -= (2 * qrSize + 2 * padding)
                // Warn if dual QR leaves very little text space
                if format.labelWidth < 120 {
                    warnings.append("Dual QR codes leave minimal space for text")
                }
            case .none:
                break
            }
        }

        // Account for manufacturer image(s) - sized as percentage of label height
        if manufacturerImagePosition != .none {
            let effectiveImageSize = manufacturerImageSize ?? 0.6
            let imageSize = format.labelHeight * effectiveImageSize

            switch manufacturerImagePosition {
            case .left, .right:
                availableWidth -= (imageSize + padding)
            case .both:
                availableWidth -= (2 * imageSize + 2 * padding)
                // Warn if dual images leave very little text space
                if format.labelWidth < 120 {
                    warnings.append("Manufacturer images on both sides leave minimal space for text")
                }
            case .none:
                break
            }
        }

        // Estimate text height
        let estimatedTextHeight = textFields.reduce(0) { $0 + ($1.estimatedHeight * fontScale) }
        let textFits = estimatedTextHeight <= availableHeight

        // Check for potential text truncation issues
        if !textFits {
            let overflow = Int(estimatedTextHeight - availableHeight)
            warnings.append("Text will be truncated (\(overflow)pt overflow) - reduce font size or remove fields")
        }

        if availableWidth < 40 {
            warnings.append("Very narrow text area - consider reducing QR size or using fewer fields")
        }

        // Check if too many fields for the label size
        if textFields.count > 5 && format.labelHeight < 72 {
            warnings.append("Small label with many fields - text will be very compact")
        }

        return LabelLayoutValidation(
            fits: textFits && availableWidth >= 40,
            estimatedTextHeight: estimatedTextHeight,
            availableHeight: availableHeight,
            availableWidth: availableWidth,
            warnings: warnings
        )
    }
}

/// Result of label layout validation
struct LabelLayoutValidation {
    let fits: Bool
    let estimatedTextHeight: CGFloat
    let availableHeight: CGFloat
    let availableWidth: CGFloat
    let warnings: [String]
}

/// Label builder preset - named configuration that can be saved and shared
struct LabelBuilderPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var config: LabelBuilderConfig
    var createdAt: Date
    var modifiedAt: Date

    // Future-proofing fields (added pre-release for easier migrations)
    var workspace_id: UUID?  // For multi-inventory sets: references Workspace entity

    init(id: UUID = UUID(), name: String, description: String, config: LabelBuilderConfig, createdAt: Date = Date(), modifiedAt: Date = Date(), workspace_id: UUID? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.config = config
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.workspace_id = workspace_id
    }

    /// Export preset as JSON for sharing
    func exportJSON() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Import preset from JSON
    static func importJSON(_ data: Data) -> LabelBuilderPreset? {
        try? JSONDecoder().decode(LabelBuilderPreset.self, from: data)
    }
}

/// Manager for storing and retrieving label builder presets
/// Uses Core Data for CloudKit sync, replacing UserDefaults
@MainActor
class LabelPresetsManager: ObservableObject {
    @Published private(set) var userPresets: [LabelBuilderPreset] = []

    private let userDefaultsKey = "molten.labelBuilder.userPresets"

    static let shared = LabelPresetsManager()

    /// Initialize with optional repository (for testing, provide a repository)
    init(repository: LabelPresetRepository? = nil) {
        // Use provided repository or get from PersistenceController (available at init time)
        self.repository = repository ?? CoreDataLabelPresetRepository(context: PersistenceController.shared.cloudContext)

        // Load presets asynchronously
        Task {
            await loadPresets()
            // Auto-migrate from UserDefaults if needed
            await migrateFromUserDefaults()
        }
    }

    /// Save a new preset or update existing one
    func savePreset(_ preset: LabelBuilderPreset) async throws {
        var presetToSave = preset
        if let existingIndex = userPresets.firstIndex(where: { $0.id == preset.id }) {
            // Update existing
            presetToSave.modifiedAt = Date()
            _ = try await repository.updatePreset(presetToSave)
            await MainActor.run {
                self.userPresets[existingIndex] = presetToSave
            }
        } else {
            // Create new
            _ = try await repository.createPreset(presetToSave)
            await MainActor.run {
                self.userPresets.append(presetToSave)
            }
        }
    }

    /// Delete a preset
    func deletePreset(_ preset: LabelBuilderPreset) async throws {
        try await repository.deletePreset(id: preset.id)
        await MainActor.run {
            self.userPresets.removeAll { $0.id == preset.id }
        }
    }

    /// Export preset to share with others
    func exportPreset(_ preset: LabelBuilderPreset) -> Data? {
        preset.exportJSON()
    }

    /// Import preset from others
    func importPreset(from data: Data) async throws {
        guard let preset = LabelBuilderPreset.importJSON(data) else {
            throw LabelPresetsError.invalidData
        }
        // Assign new ID to avoid conflicts
        let importedPreset = LabelBuilderPreset(
            id: UUID(),
            name: preset.name,
            description: preset.description,
            config: preset.config
        )
        try await savePreset(importedPreset)
    }

    /// Get all presets (user first, then built-in)
    var allPresets: [LabelBuilderPreset] {
        userPresets + LabelBuilderConfig.presets
    }

    // MARK: - Private Properties

    private let repository: LabelPresetRepository

    // MARK: - Private Methods

    private func loadPresets() async {
        do {
            let presets = try await repository.fetchAllPresets()
            await MainActor.run {
                self.userPresets = presets
            }
        } catch {
            print("❌ Failed to load presets: \(error)")
        }
    }

    /// Migrate old UserDefaults presets to Core Data (one-time migration)
    func migrateFromUserDefaults() async {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let oldPresets = try? JSONDecoder().decode([LabelBuilderPreset].self, from: data) else {
            return
        }

        print("🔄 Migrating \(oldPresets.count) presets from UserDefaults to Core Data...")

        for preset in oldPresets {
            do {
                _ = try await repository.createPreset(preset)
            } catch {
                print("❌ Failed to migrate preset '\(preset.name)': \(error)")
            }
        }

        // Clear old UserDefaults storage
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("✅ Migration complete, cleared UserDefaults storage")

        // Reload presets
        await loadPresets()
    }
}

enum LabelPresetsError: Error {
    case invalidData
}

// MARK: - Legacy Template Support (for migration)

/// Label layout template configuration (DEPRECATED - use LabelBuilderConfig)
struct LabelTemplate: Equatable, Hashable {
    let name: String
    let includeQRCode: Bool
    let dualQRCodes: Bool
    let includeManufacturer: Bool
    let includeSKU: Bool
    let includeColor: Bool
    let includeCOE: Bool
    let includeQuantity: Bool
    let includeLocation: Bool
    let includeOwner: Bool
    let qrCodeSize: CGFloat

    /// Convert to LabelBuilderConfig
    func toBuilderConfig() -> LabelBuilderConfig {
        var qrPosition: QRCodePosition = .none
        if includeQRCode {
            qrPosition = dualQRCodes ? .both : .left
        }

        var fields: [LabelTextField] = []
        if includeManufacturer { fields.append(.manufacturer) }
        if includeSKU { fields.append(.sku) }
        if includeColor { fields.append(.colorName) }
        if includeCOE { fields.append(.coe) }
        if includeLocation { fields.append(.location) }
        if includeOwner { fields.append(.owner) }

        return LabelBuilderConfig(
            qrPosition: qrPosition,
            qrSize: qrCodeSize,
            fontScale: nil,  // Use format default for legacy templates
            manufacturerImagePosition: .none,  // Legacy templates don't have manufacturer images
            manufacturerImageSize: nil,
            textFields: fields,
            textAlignment: .left,  // Default to left alignment for legacy templates
            fieldFormats: LabelFieldFormat.defaults  // Use default field formats for legacy templates
        )
    }

    static let informationDense = LabelTemplate(
        name: "Information Dense",
        includeQRCode: true,
        dualQRCodes: false,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: true,
        includeCOE: true,
        includeQuantity: true,
        includeLocation: false,
        includeOwner: false,
        qrCodeSize: 0.65
    )

    static let qrFocused = LabelTemplate(
        name: "QR Focused",
        includeQRCode: true,
        dualQRCodes: false,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: false,
        includeCOE: false,
        includeQuantity: false,
        includeLocation: false,
        includeOwner: false,
        qrCodeSize: 0.75
    )

    static let locationBased = LabelTemplate(
        name: "Location Based",
        includeQRCode: true,
        dualQRCodes: false,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: true,
        includeCOE: true,
        includeQuantity: true,
        includeLocation: true,
        includeOwner: false,
        qrCodeSize: 0.50
    )

    static let dualQR = LabelTemplate(
        name: "Dual QR",
        includeQRCode: true,
        dualQRCodes: true,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: true,
        includeCOE: false,
        includeQuantity: false,
        includeLocation: false,
        includeOwner: false,
        qrCodeSize: 0.65
    )
}

/// Label data model for a single label (one label = one physical item like one rod)
struct LabelData: Sendable {
    let stableId: String  // The stable_id of the glass item (e.g., "2wjEBu")
    let manufacturer: String?
    let sku: String?
    let colorName: String?
    let coe: String?
    let location: String?
    let owner: String?
}

#if os(iOS)
/// Service for generating printable label sheets with QR codes
@preconcurrency
class LabelPrintingService {

    // MARK: - Performance Optimization

    /// Shared CIContext for QR code generation (expensive to create)
    private let qrContext = CIContext()

    /// Cache for generated QR codes (key = stableId)
    private var qrCodeCache: [String: UIImage] = [:]

    /// Generate QR code image for a glass item with Molten logo overlay
    /// - Parameter stableId: The stable_id of the glass item (e.g., "2wjEBu")
    /// - Returns: UIImage containing the QR code with logo in center
    func generateQRCode(for stableId: String) -> UIImage {
        // Check cache first
        if let cachedQR = qrCodeCache[stableId] {
            return cachedQR
        }

        let filter = CIFilter.qrCodeGenerator()

        // Create deep link URL with stable_id
        let deepLink = "molten://g/\(stableId)"
        let data = Data(deepLink.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        // Scale QR code to appropriate size
        guard let outputImage = filter.outputImage else { return UIImage() }
        let qrSize: CGFloat = 200
        let scaleX = qrSize / outputImage.extent.width
        let scaleY = qrSize / outputImage.extent.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = qrContext.createCGImage(transformedImage, from: transformedImage.extent) else {
            return UIImage()
        }

        let qrImage = UIImage(cgImage: cgImage)

        // Overlay logo in center
        let finalImage = overlayLogoOnQRCode(qrImage: qrImage, qrSize: qrSize)

        // Cache for reuse
        qrCodeCache[stableId] = finalImage

        return finalImage
    }

    /// Overlay Molten logo in the center of QR code
    /// - Parameters:
    ///   - qrImage: The base QR code image
    ///   - qrSize: The size of the QR code
    /// - Returns: QR code with logo overlay
    private func overlayLogoOnQRCode(qrImage: UIImage, qrSize: CGFloat) -> UIImage {
        // Load logo from Assets
        guard let logo = UIImage(named: "molten-glass-logo-QR") else {
            print("⚠️ LabelPrintingService: Logo 'molten-glass-logo-QR' not found in Assets")
            return qrImage
        }

        // Logo should be about 22% of QR code size (safe with H error correction)
        let logoSize = qrSize * 0.22

        // Create graphics context
        UIGraphicsBeginImageContextWithOptions(CGSize(width: qrSize, height: qrSize), false, 0)
        defer { UIGraphicsEndImageContext() }

        // Draw QR code
        qrImage.draw(in: CGRect(x: 0, y: 0, width: qrSize, height: qrSize))

        // Draw white background circle behind logo for better contrast
        let logoRect = CGRect(
            x: (qrSize - logoSize) / 2,
            y: (qrSize - logoSize) / 2,
            width: logoSize,
            height: logoSize
        )

        // White circle slightly larger than logo
        let circleSize = logoSize * 1.1
        let circleRect = CGRect(
            x: (qrSize - circleSize) / 2,
            y: (qrSize - circleSize) / 2,
            width: circleSize,
            height: circleSize
        )

        UIColor.white.setFill()
        let circlePath = UIBezierPath(ovalIn: circleRect)
        circlePath.fill()

        // Draw logo
        logo.draw(in: logoRect)

        // Get composite image
        guard let compositeImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return qrImage
        }

        print("✅ LabelPrintingService: Logo overlay applied to QR code")
        return compositeImage
    }

    /// Generate label sheet PDF
    /// - Parameters:
    ///   - labels: Array of label data to print
    ///   - format: Avery format to use
    ///   - config: Label builder configuration
    ///   - fontScale: Font size multiplier (0.7 to 1.3)
    ///   - offsetX: Horizontal position adjustment in points (-10 to +10)
    ///   - offsetY: Vertical position adjustment in points (-10 to +10)
    ///   - startRow: Starting row (0-based) for partial sheets (default: 0)
    ///   - startColumn: Starting column (0-based) for partial sheets (default: 0)
    /// - Returns: URL to the generated PDF file in temporary storage
    func generateLabelSheet(
        labels: [LabelData],
        format: AveryFormat = .avery5160,
        config: LabelBuilderConfig = .default,
        fontScale: Double = 1.0,
        offsetX: Double = 0.0,
        offsetY: Double = 0.0,
        startRow: Int = 0,
        startColumn: Int = 0
    ) async -> URL? {
        // Create temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Molten-Labels-\(Date().timeIntervalSince1970).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: fileURL)

        // Generate PDF
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter (8.5" × 11")
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = pdfRenderer.pdfData { context in
            var labelIndex = 0
            let totalLabels = labels.count
            var isFirstPage = true

            while labelIndex < totalLabels {
                context.beginPage()

                // Draw labels on this page
                for row in 0..<format.rows {
                    for col in 0..<format.columns {
                        // Skip positions before start position on first page
                        if isFirstPage && (row < startRow || (row == startRow && col < startColumn)) {
                            continue  // Skip this position (it's before our start position)
                        }

                        if labelIndex >= totalLabels { break }

                        let labelData = labels[labelIndex]

                        // Calculate label position with user adjustments
                        let x = format.leftMargin + (CGFloat(col) * (format.labelWidth + format.horizontalGap)) + CGFloat(offsetX)
                        let y = format.topMargin + (CGFloat(row) * (format.labelHeight + format.verticalGap)) + CGFloat(offsetY)
                        let labelRect = CGRect(x: x, y: y, width: format.labelWidth, height: format.labelHeight)

                        // Draw single label
                        drawLabel(
                            labelData: labelData,
                            rect: labelRect,
                            format: format,
                            config: config,
                            fontScale: CGFloat(fontScale),
                            context: context.cgContext
                        )

                        labelIndex += 1
                    }
                    if labelIndex >= totalLabels { break }
                }

                isFirstPage = false  // After first page, start from beginning of sheet
            }
        }

        // Write PDF data to file
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing PDF: \(error)")
            return nil
        }
    }

    // MARK: - Drawing Helpers

    private func drawLabel(
        labelData: LabelData,
        rect: CGRect,
        format: AveryFormat,
        config: LabelBuilderConfig,
        fontScale: CGFloat = 1.0,
        context: CGContext
    ) {
        let padding: CGFloat = 4

        // Draw QR code(s) based on position
        var contentX = rect.minX + padding
        var contentWidth = rect.width - (padding * 2)

        if config.qrPosition != .none {
            let effectiveQRSize = config.qrSize ?? format.defaultQRSize
            let qrSize = rect.height * effectiveQRSize
            let qrImage = generateQRCode(for: labelData.stableId)

            switch config.qrPosition {
            case .left:
                // Draw left QR code
                let leftQRRect = CGRect(
                    x: rect.minX + padding,
                    y: rect.minY + (rect.height - qrSize) / 2,
                    width: qrSize,
                    height: qrSize
                )
                qrImage.draw(in: leftQRRect)

                // Adjust content area to be to the right of QR code
                contentX = leftQRRect.maxX + padding
                contentWidth = rect.maxX - contentX - padding

            case .right:
                // Draw right QR code
                let rightQRRect = CGRect(
                    x: rect.maxX - padding - qrSize,
                    y: rect.minY + (rect.height - qrSize) / 2,
                    width: qrSize,
                    height: qrSize
                )
                qrImage.draw(in: rightQRRect)

                // Content area is from left edge to QR code
                contentWidth = rightQRRect.minX - contentX - padding

            case .both:
                // Draw left QR code
                let leftQRRect = CGRect(
                    x: rect.minX + padding,
                    y: rect.minY + (rect.height - qrSize) / 2,
                    width: qrSize,
                    height: qrSize
                )
                qrImage.draw(in: leftQRRect)

                // Draw right QR code
                let rightQRRect = CGRect(
                    x: rect.maxX - padding - qrSize,
                    y: rect.minY + (rect.height - qrSize) / 2,
                    width: qrSize,
                    height: qrSize
                )
                qrImage.draw(in: rightQRRect)

                // Content area is between the two QR codes
                contentX = leftQRRect.maxX + padding
                contentWidth = rightQRRect.minX - contentX - padding

            case .none:
                break
            }
        }

        // Draw manufacturer image(s) if configured
        if config.manufacturerImagePosition != .none, let manufacturer = labelData.manufacturer {
            let effectiveImageSize = config.manufacturerImageSize ?? 0.6
            let imageSize = rect.height * effectiveImageSize

            // Try to load manufacturer logo
            // Manufacturer codes are uppercase (e.g., "EF", "BE"), but files are lowercase with _print.png suffix
            let imageName = "\(manufacturer.lowercased())_print.png"
            if let logoImage = UIImage(named: imageName) {
                switch config.manufacturerImagePosition {
                case .left:
                    // Draw left image
                    let leftImageRect = CGRect(
                        x: rect.minX + padding,
                        y: rect.minY + (rect.height - imageSize) / 2,
                        width: imageSize,
                        height: imageSize
                    )
                    logoImage.draw(in: leftImageRect)

                    // Adjust content area to be to the right of image
                    contentX = leftImageRect.maxX + padding
                    contentWidth = rect.maxX - contentX - padding

                case .right:
                    // Draw right image
                    let rightImageRect = CGRect(
                        x: rect.maxX - padding - imageSize,
                        y: rect.minY + (rect.height - imageSize) / 2,
                        width: imageSize,
                        height: imageSize
                    )
                    logoImage.draw(in: rightImageRect)

                    // Content area is from left edge to image
                    contentWidth = rightImageRect.minX - contentX - padding

                case .both:
                    // Draw left image
                    let leftImageRect = CGRect(
                        x: rect.minX + padding,
                        y: rect.minY + (rect.height - imageSize) / 2,
                        width: imageSize,
                        height: imageSize
                    )
                    logoImage.draw(in: leftImageRect)

                    // Draw right image
                    let rightImageRect = CGRect(
                        x: rect.maxX - padding - imageSize,
                        y: rect.minY + (rect.height - imageSize) / 2,
                        width: imageSize,
                        height: imageSize
                    )
                    logoImage.draw(in: rightImageRect)

                    // Content area is between the two images
                    contentX = leftImageRect.maxX + padding
                    contentWidth = rightImageRect.minX - contentX - padding

                case .none:
                    break
                }
            } else {
                print("⚠️ LabelPrintingService: Manufacturer image '\(imageName)' not found in Assets")
                print("   Expected file naming: {manufacturer}_print.png (e.g., be_print.png, cim_print.png)")
            }
        } else if config.manufacturerImagePosition != .none {
            print("ℹ️ LabelPrintingService: Manufacturer image position is \(config.manufacturerImagePosition.rawValue) but no manufacturer data available")
        }

        // Calculate total text height first for vertical centering
        var totalTextHeight: CGFloat = 0
        for field in config.textFields {
            let fieldFormat = config.format(for: field)
            let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * fontScale) : .systemFont(ofSize: fieldFormat.fontSize * fontScale)

            // Only count this field if it has data to show
            let shouldShow: Bool = {
                switch field {
                case .manufacturer: return labelData.manufacturer != nil
                case .sku: return labelData.sku != nil
                case .colorName: return labelData.colorName != nil
                case .coe: return labelData.coe != nil
                case .location: return labelData.location != nil
                case .owner: return labelData.owner != nil
                }
            }()

            if shouldShow {
                totalTextHeight += font.lineHeight + 1
            }
        }

        // Start Y position centered vertically in the available space
        let availableHeight = rect.height - (padding * 2)
        var yPosition = rect.minY + padding + max(0, (availableHeight - totalTextHeight) / 2)

        // Convert text alignment to NSTextAlignment
        let textAlignment: NSTextAlignment = {
            switch config.textAlignment {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            }
        }()

        for field in config.textFields {
            switch field {
            case .manufacturer:
                if let manufacturer = labelData.manufacturer {
                    // Convert manufacturer abbreviation to full name first
                    let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer

                    // Check if SKU already starts with full manufacturer name (case-insensitive)
                    // Only hide manufacturer if SKU literally starts with the full name (not just abbreviation)
                    let skuStartsWithManufacturer: Bool = {
                        guard let sku = labelData.sku,
                              config.textFields.contains(.sku) else {
                            return false
                        }
                        return sku.lowercased().hasPrefix(fullName.lowercased())
                    }()

                    // Only show manufacturer if SKU doesn't already start with it
                    if !skuStartsWithManufacturer {
                        let fieldFormat = config.format(for: .manufacturer)
                        let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * fontScale) : .systemFont(ofSize: fieldFormat.fontSize * fontScale)
                        yPosition = drawText(
                            fullName,
                            at: CGPoint(x: contentX, y: yPosition),
                            width: contentWidth,
                            font: font,
                            alignment: textAlignment,
                            context: context,
                            italic: fieldFormat.italic
                        )
                    }
                }

            case .sku:
                if let sku = labelData.sku {
                    let fieldFormat = config.format(for: .sku)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * fontScale) : .systemFont(ofSize: fieldFormat.fontSize * fontScale)
                    yPosition = drawText(
                        sku,
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }

            case .colorName:
                if let colorName = labelData.colorName {
                    let fieldFormat = config.format(for: .colorName)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * fontScale) : .systemFont(ofSize: fieldFormat.fontSize * fontScale)
                    yPosition = drawText(
                        colorName,
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }

            case .coe:
                if let coe = labelData.coe {
                    let fieldFormat = config.format(for: .coe)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * fontScale) : .systemFont(ofSize: fieldFormat.fontSize * fontScale)
                    yPosition = drawText(
                        "COE \(coe)",
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        color: .darkGray,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }

            case .location:
                if let location = labelData.location {
                    let fieldFormat = config.format(for: .location)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * fontScale) : .systemFont(ofSize: fieldFormat.fontSize * fontScale)
                    yPosition = drawText(
                        "📍 \(location)",
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        color: .darkGray,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }

            case .owner:
                if let owner = labelData.owner {
                    let fieldFormat = config.format(for: .owner)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * fontScale) : .systemFont(ofSize: fieldFormat.fontSize * fontScale)
                    yPosition = drawText(
                        owner,
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        color: .darkGray,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }
            }
        }
    }

    private func drawText(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor = .black,
        alignment: NSTextAlignment = .left,
        context: CGContext,
        italic: Bool = false
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        // Apply italic if requested by creating italic font descriptor
        let finalFont: UIFont
        if italic {
            let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? font.fontDescriptor
            finalFont = UIFont(descriptor: descriptor, size: font.pointSize)
        } else {
            finalFont = font
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: finalFont,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: point.x, y: point.y, width: width, height: font.lineHeight)

        attributedString.draw(in: textRect)

        return point.y + font.lineHeight + 1
    }
}
#else
// macOS stub - Label printing is iOS-only
@preconcurrency
class LabelPrintingService {
    // Label printing requires UIKit (UIImage, UIFont, UIColor) which is iOS-only
    // On macOS, this service is non-functional
}
#endif
