import Cocoa

// MARK: - Speed Settings Window

class SpeedSettingsWindow: ManagedWindow {
    var config: AppConfig
    var onSave: ((AppConfig) -> Void)?
    
    var interKeyDelaySlider: NSSlider!
    var interChunkDelaySlider: NSSlider!
    var chunkSizeSlider: NSSlider!
    var batchSizeSlider: NSSlider!
    
    var interKeyDelayValue: NSTextField!
    var interChunkDelayValue: NSTextField!
    var chunkSizeValue: NSTextField!
    var batchSizeValue: NSTextField!
    var estimateLabel: NSTextField!
    
    struct Preset {
        let name: String
        let interKeyDelay: UInt32
        let interChunkDelay: UInt32
        let chunkSize: Int
        let batchSize: Int
        let shiftToggleDelay: UInt32
    }
    
    static let presets: [Preset] = [
        Preset(name: "fast", interKeyDelay: 2000, interChunkDelay: 5000, chunkSize: 200, batchSize: 15, shiftToggleDelay: 15000),
        Preset(name: "balanced", interKeyDelay: 5000, interChunkDelay: 10000, chunkSize: 100, batchSize: 10, shiftToggleDelay: 30000),
        Preset(name: "safe", interKeyDelay: 20000, interChunkDelay: 50000, chunkSize: 50, batchSize: 5, shiftToggleDelay: 50000),
    ]
    
    static func presetDisplayName(_ name: String) -> String {
        switch name {
        case "fast": return L10n.presetFast
        case "balanced": return L10n.presetBalanced
        case "safe": return L10n.presetSafe
        default: return name
        }
    }
    
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        self.config = config
        self.onSave = onSave
        
        super.init(size: NSSize(width: 400, height: 420), title: L10n.speedSettingsTitle)
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 420))
        let margin = 20
        let width = 360
        var y = 380
        
        // — Presets —
        let presetBox = NSView(frame: NSRect(x: margin, y: y - 30, width: width, height: 30))
        var px = 0
        for (i, preset) in Self.presets.enumerated() {
            let btn = NSButton(title: Self.presetDisplayName(preset.name), target: self, action: #selector(presetPressed(_:)))
            btn.frame = NSRect(x: px, y: 0, width: 110, height: 28)
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 12)
            btn.tag = i
            presetBox.addSubview(btn)
            px += 120
        }
        contentView.addSubview(presetBox)
        y -= 50
        
        // — 4 Sliders —
        let r1 = addSliderRow(to: contentView, y: &y, width: width, margin: margin,
                              label: L10n.interKeyDelayLabel,
                              hint: L10n.hintInterKeyDelay,
                              min: 1, max: 50,
                              value: Double(config.interKeyDelay) / 1000.0)
        interKeyDelaySlider = r1.slider
        interKeyDelayValue = r1.valueLabel
        
        let r2 = addSliderRow(to: contentView, y: &y, width: width, margin: margin,
                              label: L10n.interChunkDelayLabel,
                              hint: L10n.hintInterChunkDelay,
                              min: 1, max: 100,
                              value: Double(config.interChunkDelay) / 1000.0)
        interChunkDelaySlider = r2.slider
        interChunkDelayValue = r2.valueLabel
        
        let r3 = addSliderRow(to: contentView, y: &y, width: width, margin: margin,
                              label: L10n.chunkSizeLabel,
                              hint: L10n.hintChunkSize,
                              min: 10, max: 500,
                              value: Double(config.chunkSize))
        chunkSizeSlider = r3.slider
        chunkSizeValue = r3.valueLabel
        
        let r4 = addSliderRow(to: contentView, y: &y, width: width, margin: margin,
                              label: L10n.batchSizeLabel,
                              hint: L10n.hintBatchSize,
                              min: 1, max: 50,
                              value: Double(config.batchSize))
        batchSizeSlider = r4.slider
        batchSizeValue = r4.valueLabel
        
        // — Estimated speed —
        y -= 8
        estimateLabel = NSTextField(labelWithString: "")
        estimateLabel.frame = NSRect(x: margin, y: y, width: width, height: 16)
        estimateLabel.font = NSFont.systemFont(ofSize: 11)
        estimateLabel.textColor = .secondaryLabelColor
        estimateLabel.alignment = .center
        contentView.addSubview(estimateLabel)
        
        // — Bottom buttons —
        let saveButton = NSButton(title: L10n.confirm, target: self, action: #selector(savePressed))
        saveButton.frame = NSRect(x: 280, y: 16, width: 100, height: 32)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)
        
        let resetButton = NSButton(title: L10n.resetDefaults, target: self, action: #selector(resetPressed))
        resetButton.frame = NSRect(x: margin, y: 16, width: 100, height: 32)
        resetButton.bezelStyle = .rounded
        contentView.addSubview(resetButton)
        
        self.contentView = contentView
        updateAllValueLabels()
        updateEstimate()
    }
    
    override func releaseResources() {
        onSave = nil
    }
    
    // MARK: - Slider Row (compact layout: label+value on same line, slider below, tiny hint)
    
    private func addSliderRow(to view: NSView, y: inout Int, width: Int, margin: Int, label: String, hint: String, min: Double, max: Double, value: Double) -> (slider: NSSlider, valueLabel: NSTextField) {
        
        // Title + value on same line
        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.frame = NSRect(x: margin, y: y, width: 200, height: 16)
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(titleLabel)
        
        let valueLabel = NSTextField(labelWithString: "")
        valueLabel.frame = NSRect(x: margin + width - 70, y: y, width: 70, height: 16)
        valueLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.textColor = .labelColor
        view.addSubview(valueLabel)
        
        y -= 20
        
        // Slider
        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: #selector(sliderChanged(_:)))
        slider.frame = NSRect(x: margin, y: y, width: width, height: 18)
        slider.isContinuous = true
        view.addSubview(slider)
        
        y -= 16
        
        // Hint (smallest font)
        let hintLabel = NSTextField(labelWithString: hint)
        hintLabel.frame = NSRect(x: margin, y: y, width: width, height: 12)
        hintLabel.font = NSFont.systemFont(ofSize: 9.5)
        hintLabel.textColor = .tertiaryLabelColor
        view.addSubview(hintLabel)
        
        y -= 22
        
        return (slider, valueLabel)
    }
    
    // MARK: - Actions
    
    @objc func sliderChanged(_ sender: NSSlider) {
        updateAllValueLabels()
        updateEstimate()
    }
    
    @objc func presetPressed(_ sender: NSButton) {
        let preset = Self.presets[sender.tag]
        interKeyDelaySlider.doubleValue = Double(preset.interKeyDelay) / 1000.0
        interChunkDelaySlider.doubleValue = Double(preset.interChunkDelay) / 1000.0
        chunkSizeSlider.doubleValue = Double(preset.chunkSize)
        batchSizeSlider.doubleValue = Double(preset.batchSize)
        // shiftToggleDelay has no slider yet — store directly on config
        config.shiftToggleDelay = preset.shiftToggleDelay
        updateAllValueLabels()
        updateEstimate()
    }
    
    @objc func savePressed() {
        config.interKeyDelay = UInt32(interKeyDelaySlider.doubleValue * 1000)
        config.interChunkDelay = UInt32(interChunkDelaySlider.doubleValue * 1000)
        config.chunkSize = Int(chunkSizeSlider.doubleValue)
        config.batchSize = Int(batchSizeSlider.doubleValue)
        onSave?(config)
        close()
    }
    
    @objc func resetPressed() {
        let d = AppConfig.defaultConfig
        interKeyDelaySlider.doubleValue = Double(d.interKeyDelay) / 1000.0
        interChunkDelaySlider.doubleValue = Double(d.interChunkDelay) / 1000.0
        chunkSizeSlider.doubleValue = Double(d.chunkSize)
        batchSizeSlider.doubleValue = Double(d.batchSize)
        config.shiftToggleDelay = d.shiftToggleDelay
        updateAllValueLabels()
        updateEstimate()
    }
    
    // MARK: - UI Updates
    
    private func updateAllValueLabels() {
        interKeyDelayValue?.stringValue = formatMs(interKeyDelaySlider.doubleValue)
        interChunkDelayValue?.stringValue = formatMs(interChunkDelaySlider.doubleValue)
        chunkSizeValue?.stringValue = "\(Int(chunkSizeSlider.doubleValue))"
        batchSizeValue?.stringValue = "\(Int(batchSizeSlider.doubleValue))"
    }
    
    private func updateEstimate() {
        let delayMs = interKeyDelaySlider.doubleValue
        let batchSize = Int(batchSizeSlider.doubleValue)
        let msPerBatch = 5.0 + delayMs
        let charsPerSecond = Double(batchSize) / (msPerBatch / 1000.0)
        estimateLabel?.stringValue = L10n.estimateSpeed(Int(charsPerSecond))
    }
    
    private func formatMs(_ ms: Double) -> String {
        if ms >= 1.0 {
            return ms == Double(Int(ms)) ? "\(Int(ms)) ms" : String(format: "%.1f ms", ms)
        }
        return String(format: "%.0f μs", ms * 1000)
    }
}
