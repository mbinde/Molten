# Glass Scraper TODO

## New Manufacturers to Add

### Simax
- **Type**: Borosilicate tubing manufacturer
- **COE**: 33
- **Website**: TBD
- **Products**: Tubing, rods
- **Priority**: High

### Schott
- **Type**: Borosilicate glass manufacturer
- **COE**: 33
- **Website**: TBD
- **Products**: Tubing, specialty glass
- **Priority**: High

### Lauscha
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: TBD
- **Products**: TBD
- **Priority**: High

### Devardi
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: TBD
- **Products**: TBD
- **Priority**: High

### Satake
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: TBD
- **Products**: TBD
- **Priority**: High

### Val Cox
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: TBD
- **Products**: TBD
- **Priority**: High

### Youghiogheny
- **Type**: Glass manufacturer
- **COE**: 96
- **Website**: TBD
- **Products**: TBD (likely sheet glass)
- **Priority**: High
- **Notes**: First COE 96 manufacturer in the system

### BoroGlow
- **Type**: Borosilicate glass manufacturer
- **COE**: 33
- **Website**: https://lampworksupply.com/category/boroglow-glass
- **Products**: TBD
- **Priority**: High
- **Notes**: Available through Lampwork Supply

### Chinese Boro
- **Type**: Borosilicate glass manufacturer
- **COE**: 33
- **Website**: https://artistryinglass.on.ca/BEADMAKING-and-FLAMEWORKING/chinese-glass/chinese-borosilicate-rod/
- **Products**: Borosilicate rod
- **Priority**: High
- **Notes**: Available through Artistry in Glass

### Lunar Glass
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: https://artistryinglass.on.ca/BEADMAKING-and-FLAMEWORKING/lunar-glass/
- **Products**: TBD
- **Priority**: High
- **Notes**: Available through Artistry in Glass

### Dream Tubing Co
- **Type**: Borosilicate tubing manufacturer
- **COE**: 33 (likely)
- **Website**: https://lampworksupply.com/category/dream-tubing-co
- **Products**: Tubing
- **Priority**: High
- **Notes**: Available through Lampwork Supply

### Parramore Glass
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: TBD - Need to find
- **Products**: TBD
- **Priority**: High
- **Notes**: Website needs to be located

### UST Glass
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: https://www.ustglass.com/product-category/color/
- **Products**: Color glass
- **Priority**: High

### PDX Tubing Co
- **Type**: Borosilicate tubing manufacturer
- **COE**: 33 (likely)
- **Website**: https://pdxtubingco.com/
- **Products**: Tubing
- **Priority**: High

### Uro
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: TBD - Investigate via https://www.delphiglass.com/page/main_glass
- **Products**: TBD
- **Priority**: Medium
- **Notes**: Listed on Delphi Glass

### Kokomo
- **Type**: Glass manufacturer
- **COE**: 96 (likely - art glass/stained glass)
- **Website**: TBD - Investigate via https://www.delphiglass.com/page/main_glass
- **Products**: TBD (likely sheet glass)
- **Priority**: Medium
- **Notes**: Listed on Delphi Glass

### Oceana
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: TBD - Investigate via https://www.delphiglass.com/page/main_glass
- **Products**: TBD
- **Priority**: Medium
- **Notes**: Listed on Delphi Glass

### Van Gogh
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: TBD - Investigate via https://www.delphiglass.com/page/main_glass
- **Products**: TBD (likely art glass)
- **Priority**: Medium
- **Notes**: Listed on Delphi Glass

### Tiffany Today
- **Type**: Glass manufacturer
- **COE**: TBD
- **Website**: TBD - Investigate via https://www.delphiglass.com/page/main_glass
- **Products**: TBD
- **Priority**: Medium
- **Notes**: Listed on Delphi Glass

### Y96
- **Type**: Glass manufacturer
- **COE**: 96 (indicated by name)
- **Website**: TBD - Investigate via https://www.delphiglass.com/page/main_glass
- **Products**: TBD
- **Priority**: Medium
- **Notes**: Listed on Delphi Glass, name suggests COE 96

## Product Type Enhancements

### Add Tubing Support
- Currently supported types: rod, frit, sheet, stringer, tube, other
- Need to ensure "tubing" is properly categorized
- Check if "tube" vs "tubing" distinction matters
- Update scrapers to properly detect and categorize tubing products

## Future Enhancements

- [ ] Add stock_type tracking for all manufacturers (currently only Double Helix)
- [ ] Implement start_date and end_date tracking for product availability
- [ ] Add more color mappings to color_extractor.py
- [ ] Consider adding product images to the database
- [ ] Add automatic retry on network errors
- [ ] Validate image URLs before saving

## Known Issues

- Origin Glass: All products share the same URL (single-page listing)
- Bullseye: Large catalog (~2900 items) slows down scraping
- Some manufacturers don't provide SKU codes (using hash-based IDs)
