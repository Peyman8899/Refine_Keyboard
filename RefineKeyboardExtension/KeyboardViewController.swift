import UIKit
import AVFoundation

final class KeyboardViewController: UIInputViewController {
    private enum KeyboardMode {
        case letters
        case numbers
        case symbols
        case emoji
        case aiReview
        case customToneInput
    }

    private let client = RewriteClient()
    private var outputLanguage = KeyboardSettings.rewriteLanguage
    private var languageButton: UIButton?
    private var statusTask: Task<Void, Never>?
    private var deleteTimer: Timer?
    private let keyboardStack = UIStackView()
    private var keyboardHeightConstraint: NSLayoutConstraint?
    private var fastLetterRows: [FastKeyRow] = []
    private var shiftButton: UIButton?
    private var emojiScrollView: UIScrollView?
    private var emojiCategoryAnchors: [UIView] = []
    private var isShifted = true
    private var capsLocked = false
    private var lastShiftTapTime: Date?
    private var keyboardMode: KeyboardMode = .letters
    private var lastRewriteCharacterCount: Int?
    private let keyPreview = KeyPreviewView()
    private let translationBanner = TranslationBannerView()
    private var bannerDismissTask: Task<Void, Never>?
    private var lastTranslation: String?
    private var currentTone: RewriteMode = .polish
    private var toneButton: UIButton?
    private var aiOriginalText = ""
    private var aiRefinedText = ""
    private var aiUsingSelection = false
    private var aiContextBefore = ""
    private var aiContextAfter = ""
    private var aiCustomInstruction = ""
    private var aiTranslatedText: String? = nil   // cached for target-lang speech
    // Custom tone input state
    private var customToneBuffer = ""
    private var customToneNameBuffer = ""
    private var customToneNaming = false
    private weak var customToneDisplayLabel: UILabel?
    private weak var customToneNameLabel: UILabel?
    private var customToneCursorTimer: Timer?
    private enum SpeechTarget { case english, target }
    private var currentSpeechTarget: SpeechTarget? = nil
    private var audioPlayer: AVAudioPlayer?
    private var speakTask: Task<Void, Never>?
    private weak var currentAIReviewView: AIReviewView?
    private var translateLangButton: UIButton?
    private var translateButton: UIButton?

    private static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }

    private let keyboardBackground = KeyboardViewController.dynamicColor(
        light: UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1),
        dark: UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
    )
    private let letterKeyBackground = KeyboardViewController.dynamicColor(
        light: .white,
        dark: UIColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1)
    )
    private let specialKeyBackground = KeyboardViewController.dynamicColor(
        light: UIColor(red: 0.68, green: 0.70, blue: 0.75, alpha: 1),
        dark: UIColor(red: 0.14, green: 0.14, blue: 0.15, alpha: 1)
    )
    private let actionPillBackground = KeyboardViewController.dynamicColor(
        light: UIColor(red: 0.92, green: 0.93, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.18, green: 0.20, blue: 0.26, alpha: 1)
    )

    private let emojiCategories: [(String, [[String]])] = [
        ("FREQUENTLY USED", [
            ["😁", "💕", "❤️", "😊", "✌️", "😎", "👍", "🎉"],
            ["😍", "😭", "😉", "🎵", "😂", "🌞", "🙁", "😔"],
            ["☺️", "👀", "💅", "🙏", "👌", "😏", "🤷", "😐"]
        ]),
        ("SMILEYS & PEOPLE", [
            ["😀", "🥹", "☺️", "😃", "😅", "😊", "😄", "😂"],
            ["😇", "😆", "🤣", "🙂", "😉", "😍", "😘", "😜"],
            ["🤔", "😬", "🙄", "😴", "😢", "😡", "👏", "👋"]
        ]),
        ("ANIMALS & NATURE", [
            ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼"],
            ["🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔"],
            ["🌸", "🌹", "🌞", "🌙", "⭐️", "🔥", "🌈", "🌎"]
        ]),
        ("FOOD & DRINK", [
            ["🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓"],
            ["🍒", "🍑", "🥑", "🍔", "🍟", "🍕", "🌮", "🍣"],
            ["🍩", "🍪", "🎂", "☕️", "🍺", "🍷", "🥂", "🧃"]
        ]),
        ("ACTIVITY", [
            ["⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🎱", "🏓"],
            ["🏃", "💃", "🕺", "🚴", "🏆", "🎮", "🎲", "🎯"],
            ["🎵", "🎤", "🎧", "🎬", "🎨", "🎭", "🎸", "🎹"]
        ]),
        ("TRAVEL & OBJECTS", [
            ["🚗", "🚕", "🚌", "🚎", "🏎️", "🚓", "✈️", "🚀"],
            ["🏠", "🏢", "🏝️", "⛰️", "⌚️", "📱", "💻", "⌨️"],
            ["💡", "📌", "📎", "✂️", "🔒", "🔑", "❤️", "✅"]
        ])
    ]

    private let languages = [
        "Auto", "English", "Spanish", "French", "German", "Italian", "Portuguese", "Dutch",
        "Swedish", "Norwegian", "Danish", "Finnish", "Icelandic", "Irish", "Welsh",
        "Polish", "Czech", "Slovak", "Hungarian", "Romanian", "Bulgarian", "Croatian",
        "Serbian", "Slovenian", "Greek", "Turkish", "Russian", "Ukrainian", "Hebrew",
        "Arabic", "Persian", "Urdu", "Hindi", "Bengali", "Punjabi", "Gujarati",
        "Tamil", "Telugu", "Malayalam", "Kannada", "Marathi", "Nepali", "Sinhala",
        "Chinese Simplified", "Chinese Traditional", "Japanese", "Korean", "Vietnamese",
        "Thai", "Indonesian", "Malay", "Filipino", "Swahili", "Amharic", "Yoruba",
        "Igbo", "Hausa", "Zulu", "Afrikaans", "Albanian", "Armenian", "Azerbaijani",
        "Basque", "Catalan", "Estonian", "Georgian", "Kazakh", "Latvian", "Lithuanian",
        "Macedonian", "Mongolian", "Pashto", "Somali", "Tagalog"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardHeightConstraint = view.heightAnchor.constraint(equalToConstant: 262)
        keyboardHeightConstraint?.priority = .defaultHigh
        keyboardHeightConstraint?.isActive = true
        setupKeyboard()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            renderKeyboard()
        }
    }

    private func setupKeyboard() {
        view.backgroundColor = keyboardBackground

        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6)
        ])

        // ── Three-box action row: [AI ✦] [EN · Refine ⌃⌄] [FA · Translate] ──
        let actionRow = UIStackView()
        actionRow.axis = .horizontal
        actionRow.spacing = 6
        actionRow.distribution = .fill
        actionRow.heightAnchor.constraint(equalToConstant: 44).isActive = true

        // AI box
        let aiBox = UIView()
        aiBox.backgroundColor = actionPillBackground
        aiBox.layer.cornerRadius = 12
        aiBox.layer.masksToBounds = true
        aiBox.layer.borderWidth = 0.5
        aiBox.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
        aiBox.widthAnchor.constraint(equalToConstant: 64).isActive = true
        let aiBtn = UIButton(type: .system)
        let aiSym = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        aiBtn.setImage(UIImage(systemName: "sparkles", withConfiguration: aiSym), for: .normal)
        aiBtn.setTitle(" AI", for: .normal)
        aiBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        aiBtn.tintColor = .systemBlue
        aiBtn.setTitleColor(.systemBlue, for: .normal)
        aiBtn.translatesAutoresizingMaskIntoConstraints = false
        aiBox.addSubview(aiBtn)
        NSLayoutConstraint.activate([
            aiBtn.leadingAnchor.constraint(equalTo: aiBox.leadingAnchor),
            aiBtn.trailingAnchor.constraint(equalTo: aiBox.trailingAnchor),
            aiBtn.topAnchor.constraint(equalTo: aiBox.topAnchor),
            aiBtn.bottomAnchor.constraint(equalTo: aiBox.bottomAnchor),
        ])
        aiBtn.addAction(UIAction { [weak self] _ in self?.triggerAIReview() }, for: .touchUpInside)

        let (box1, langBtn1, toneBtn1) = makeBox(
            langIcon: "globe",
            langTitle: languageDisplayTitle(),
            actionIcon: toneIconName(for: currentTone),
            actionTitle: toneName(for: currentTone),
            showsChevron: true
        )
        languageButton = langBtn1
        langBtn1.menu = makeRewriteLanguageMenu()
        langBtn1.showsMenuAsPrimaryAction = true
        toneButton = toneBtn1
        toneBtn1.menu = makeToneMenu()
        toneBtn1.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.refineCurrentText(mode: self.currentTone)
        }, for: .touchUpInside)

        let (box2, trLangBtn2, trBtn2) = makeBox(
            langIcon: "arrow.right.circle.fill",
            langTitle: translateLanguageDisplayTitle(),
            actionIcon: "character.bubble.fill",
            actionTitle: "Translate",
            showsChevron: false
        )
        translateLangButton = trLangBtn2
        trLangBtn2.menu = makeTranslateLanguageMenu()
        trLangBtn2.showsMenuAsPrimaryAction = true
        translateButton = trBtn2
        trBtn2.addAction(UIAction { [weak self] _ in
            self?.translateSelectedText()
        }, for: .touchUpInside)

        actionRow.addArrangedSubview(aiBox)
        actionRow.addArrangedSubview(box1)
        actionRow.addArrangedSubview(box2)
        box1.widthAnchor.constraint(equalToConstant: 164).isActive = true
        root.addArrangedSubview(actionRow)

        keyboardStack.axis = .vertical
        keyboardStack.spacing = 6
        keyboardStack.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(keyboardStack)

        keyPreview.keyFillColor = letterKeyBackground
        view.addSubview(keyPreview)

        view.addSubview(translationBanner)
        NSLayoutConstraint.activate([
            translationBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            translationBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            translationBanner.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
        ])
        translationBanner.onTap = { [weak self] in
            guard let self else { return }
            if let text = self.lastTranslation {
                UIPasteboard.general.string = text
                self.showStatus("Copied!")
            }
            self.translationBanner.hide()
        }
        translationBanner.onDismiss = { [weak self] in
            self?.translationBanner.hide()
        }

        renderKeyboard()
    }

    private func renderKeyboard() {
        keyboardStack.arrangedSubviews.forEach { view in
            keyboardStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        fastLetterRows.removeAll()
        shiftButton = nil
        emojiScrollView = nil
        emojiCategoryAnchors.removeAll()
        customToneCursorTimer?.invalidate()
        customToneCursorTimer = nil
        currentAIReviewView = nil
        customToneDisplayLabel = nil
        customToneNameLabel = nil
        keyboardHeightConstraint?.constant = keyboardMode == .aiReview ? 340
                                           : keyboardMode == .customToneInput ? 298 : 262

        switch keyboardMode {
        case .letters:         renderLetterKeyboard()
        case .numbers:         renderNumberKeyboard()
        case .symbols:         renderSymbolsKeyboard()
        case .emoji:           renderEmojiKeyboard()
        case .aiReview:        renderAIReviewKeyboard()
        case .customToneInput: renderCustomToneKeyboard()
        }
    }

    private func renderLetterKeyboard() {
        keyboardStack.addArrangedSubview(makeLetterFastRow("qwertyuiop"))
        keyboardStack.addArrangedSubview(makeLetterFastRow("asdfghjkl", sideInset: 20))
        keyboardStack.addArrangedSubview(makeThirdLetterRow())
        keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "123"))
    }

    private func makeLetterFastRow(_ letters: String, sideInset: CGFloat = 0) -> FastKeyRow {
        let row = FastKeyRow(sideInset: sideInset, background: letterKeyBackground)
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true
        row.keyPreview = keyPreview
        row.previewContainer = view
        for char in letters {
            let base = String(char)
            let display = (isShifted || capsLocked) ? base.uppercased() : base.lowercased()
            row.addKey(base: base, display: display) { [weak self] in
                guard let self else { return }
                self.insertUserText((self.isShifted || self.capsLocked) ? base.uppercased() : base.lowercased())
                if self.isShifted && !self.capsLocked {
                    self.isShifted = false
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.fastLetterRows.forEach { $0.refreshCasing(toUpper: false) }
                        self.updateShiftAppearance()
                    }
                }
            }
        }
        fastLetterRows.append(row)
        return row
    }

    private func renderNumberKeyboard() {
        keyboardStack.addArrangedSubview(makeTextRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]))
        keyboardStack.addArrangedSubview(makeTextRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]))
        keyboardStack.addArrangedSubview(makeSymbolRow(cornerTitle: "#+=") { [weak self] in
            self?.keyboardMode = .symbols
            self?.renderKeyboard()
        })
        keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "ABC"))
    }

    private func renderSymbolsKeyboard() {
        keyboardStack.addArrangedSubview(makeTextRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]))
        keyboardStack.addArrangedSubview(makeTextRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]))
        keyboardStack.addArrangedSubview(makeSymbolRow(cornerTitle: "123") { [weak self] in
            self?.keyboardMode = .numbers
            self?.renderKeyboard()
        })
        keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "ABC"))
    }

    private func renderEmojiKeyboard() {
        keyboardStack.addArrangedSubview(makeEmojiScrollView())
        keyboardStack.addArrangedSubview(makeEmojiTabsRow())
    }

    private func makeCommandRow(modeTitle: String) -> UIStackView {
        let commandRow = UIStackView()
        commandRow.axis = .horizontal
        commandRow.spacing = 6
        commandRow.distribution = .fill

        let mode = makeSystemButton(title: modeTitle)
        mode.widthAnchor.constraint(equalToConstant: 58).isActive = true
        addTapAction(to: mode) { [weak self] in
            guard let self else { return }
            self.keyboardMode = modeTitle == "ABC" ? .letters : .numbers
            self.renderKeyboard()
        }
        commandRow.addArrangedSubview(mode)

        let emoji = makeSystemButton(title: "☺")
        emoji.widthAnchor.constraint(equalToConstant: 50).isActive = true
        addTapAction(to: emoji) { [weak self] in
            guard let self else { return }
            self.keyboardMode = .emoji
            self.renderKeyboard()
        }
        commandRow.addArrangedSubview(emoji)

        let space = makeKeyButton(title: "space", showsPreview: false)
        addCharacterAction(to: space) { [weak self] in
            self?.insertCharacter(" ")
        }
        commandRow.addArrangedSubview(space)

        let enter = makeSystemButton(title: "return")
        enter.widthAnchor.constraint(equalToConstant: 82).isActive = true
        addCharacterAction(to: enter) { [weak self] in
            self?.insertCharacter("\n")
        }
        commandRow.addArrangedSubview(enter)

        return commandRow
    }

    private func triggerAIReview() {
        guard hasFullAccess else { showStatus("Enable Full Access"); return }
        guard KeyboardSettings.isSubscriptionActive else { showStatus("Subscribe in app"); return }

        let selected = textDocumentProxy.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        aiUsingSelection = !selected.isEmpty
        if aiUsingSelection {
            aiOriginalText = selected
            aiContextBefore = ""; aiContextAfter = ""
        } else {
            aiContextBefore = textDocumentProxy.documentContextBeforeInput ?? ""
            aiContextAfter  = textDocumentProxy.documentContextAfterInput ?? ""
            aiOriginalText  = (aiContextBefore + aiContextAfter).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !aiOriginalText.isEmpty else { showStatus("Type or select text"); return }

        stopSpeaking()
        aiRefinedText = ""
        aiTranslatedText = nil
        aiCustomInstruction = ""
        keyboardMode = .aiReview
        renderKeyboard()
        currentAIReviewView?.showOriginalText(aiOriginalText)
    }

    private func runAIRefine(tone: RewriteMode, customInstruction: String = "") {
        aiTranslatedText = nil
        currentAIReviewView?.setLoading(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                let refined = try await client.rewrite(
                    text: aiOriginalText, mode: tone,
                    language: outputLanguage, customInstruction: customInstruction)
                await MainActor.run {
                    self.aiRefinedText = refined
                    self.currentAIReviewView?.setContent(original: self.aiOriginalText, refined: refined)
                }
            } catch {
                await MainActor.run { self.currentAIReviewView?.showError(self.message(for: error)) }
            }
        }
    }

    private func stopSpeaking() {
        speakTask?.cancel()
        speakTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        currentSpeechTarget = nil
    }

    private func speakWithAPI(_ text: String, target: SpeechTarget, onFail: @escaping () -> Void) {
        speakTask?.cancel()
        audioPlayer?.stop()
        audioPlayer = nil

        speakTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = URL(string: KeyboardSettings.speakEndpoint)!
                var req = URLRequest(url: url, timeoutInterval: 30)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue(KeyboardSettings.appSecret, forHTTPHeaderField: "X-App-Secret")
                req.httpBody = try JSONEncoder().encode(["text": text, "voice": "nova"])
                let (data, _) = try await URLSession.shared.data(for: req)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    do {
                        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                                         options: [.mixWithOthers, .duckOthers])
                        try AVAudioSession.sharedInstance().setActive(true)
                        let player = try AVAudioPlayer(data: data)
                        player.delegate = self
                        player.play()
                        self.audioPlayer = player
                        self.currentSpeechTarget = target
                    } catch {
                        onFail()
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run { onFail() }
                }
            }
        }
    }

    private func renderAIReviewKeyboard() {
        let sourceLangCode = outputLanguage == "Auto" ? "Auto" : languageCode(for: outputLanguage)
        let reviewView = AIReviewView(pillBackground: actionPillBackground,
                                     sourceLangCode: sourceLangCode,
                                     targetLangCode: translateLanguageDisplayTitle())
        reviewView.currentTone = currentTone
        reviewView.setContent(original: aiOriginalText, refined: aiRefinedText)
        reviewView.reloadSavedTones()
        reviewView.onCustomToneOpen = { [weak self] in
            guard let self else { return }
            self.keyboardMode = .customToneInput
            self.renderKeyboard()
        }
        reviewView.onSavedToneSelected = { [weak self] instruction in
            guard let self else { return }
            self.currentTone = .custom
            self.aiCustomInstruction = instruction
            self.aiRefinedText = ""
            self.currentAIReviewView?.currentTone = .custom
            self.currentAIReviewView?.setContent(original: self.aiOriginalText, refined: "")
            self.runAIRefine(tone: .custom, customInstruction: instruction)
        }

        reviewView.onToneChange = { [weak self] tone, customInstruction in
            guard let self else { return }
            self.currentTone = tone
            self.aiCustomInstruction = customInstruction
            self.currentAIReviewView?.currentTone = tone
            self.aiRefinedText = ""
            self.currentAIReviewView?.setContent(original: self.aiOriginalText, refined: "")
            self.runAIRefine(tone: tone, customInstruction: customInstruction)
        }
        reviewView.onInsert = { [weak self] in
            guard let self else { return }
            self.stopSpeaking()
            let textToInsert = self.aiRefinedText.isEmpty ? self.aiOriginalText : self.aiRefinedText
            guard !textToInsert.isEmpty else { return }
            if self.aiUsingSelection {
                self.textDocumentProxy.insertText(textToInsert)
                self.lastRewriteCharacterCount = nil
            } else {
                self.replaceCurrentDraft(contextBeforeInput: self.aiContextBefore,
                                         contextAfterInput: self.aiContextAfter,
                                         refined: textToInsert)
            }
            self.keyboardMode = .letters
            self.renderKeyboard()
        }
        reviewView.onPlayEN = { [weak self] in
            guard let self else { return }
            let textToSpeak = self.aiRefinedText.isEmpty ? self.aiOriginalText : self.aiRefinedText
            guard !textToSpeak.isEmpty else { return }
            if self.currentSpeechTarget == .english && self.audioPlayer?.isPlaying == true {
                self.stopSpeaking()
                self.currentAIReviewView?.setPlayingEN(false)
            } else {
                self.stopSpeaking()
                self.currentAIReviewView?.setPlayingEN(true)
                self.speakWithAPI(textToSpeak, target: .english) { [weak self] in
                    self?.currentSpeechTarget = nil
                    self?.currentAIReviewView?.setPlayingEN(false)
                }
            }
        }
        reviewView.onPlayTarget = { [weak self] in
            guard let self else { return }
            let textToSpeak = self.aiRefinedText.isEmpty ? self.aiOriginalText : self.aiRefinedText
            guard !textToSpeak.isEmpty else { return }
            if self.currentSpeechTarget == .target && self.audioPlayer?.isPlaying == true {
                self.stopSpeaking()
                self.currentAIReviewView?.setPlayingTarget(false)
                return
            }
            self.stopSpeaking()
            let targetLang = KeyboardSettings.translateLanguage

            func speak(_ text: String) {
                self.currentAIReviewView?.setPlayingTarget(true)
                self.speakWithAPI(text, target: .target) { [weak self] in
                    self?.currentSpeechTarget = nil
                    self?.currentAIReviewView?.setPlayingTarget(false)
                }
            }

            if let cached = self.aiTranslatedText {
                speak(cached)
            } else {
                self.currentAIReviewView?.setTargetLoading(true)
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let translated = try await self.client.rewrite(
                            text: textToSpeak, mode: .translate, language: targetLang,
                            customInstruction: "")
                        await MainActor.run {
                            self.aiTranslatedText = translated
                            self.currentAIReviewView?.setTargetLoading(false)
                            speak(translated)
                        }
                    } catch {
                        await MainActor.run {
                            self.currentAIReviewView?.setTargetLoading(false)
                            self.currentAIReviewView?.showError("Translation failed — try again")
                        }
                    }
                }
            }
        }
        reviewView.onBack = { [weak self] in
            self?.stopSpeaking()
            self?.keyboardMode = .letters
            self?.renderKeyboard()
        }

        currentAIReviewView = reviewView
        keyboardStack.addArrangedSubview(reviewView)
    }

    private func renderCustomToneKeyboard() {
        customToneNaming = false
        customToneNameBuffer = ""

        let pillBg = UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1) : UIColor.white }
        let headerBg = UIColor { t in t.userInterfaceStyle == .dark
            ? UIColor(white: 0.12, alpha: 1) : UIColor(white: 0.86, alpha: 1) }

        // ── Two-row header (86pt) ─────────────────────────────────────
        let headerView = UIView()
        headerView.backgroundColor = headerBg
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.heightAnchor.constraint(equalToConstant: 86).isActive = true

        // × Cancel
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setImage(UIImage(systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)), for: .normal)
        cancelBtn.tintColor = .secondaryLabel
        cancelBtn.addAction(UIAction { [weak self] _ in
            self?.customToneBuffer = ""
            self?.customToneNameBuffer = ""
            self?.keyboardMode = .aiReview
            self?.renderKeyboard()
        }, for: .touchUpInside)

        // ── Row 1: "TONE" label + description pill ────────────────────
        let toneTag = makeFieldTag("TONE", active: true)

        let descPill = UIView()
        descPill.backgroundColor = pillBg
        descPill.layer.cornerRadius = 9
        descPill.layer.borderWidth = 1.5
        descPill.layer.borderColor = UIColor.systemBlue.cgColor   // active by default

        let toneTextLabel = UILabel()
        toneTextLabel.text = customToneBuffer.isEmpty ? "describe your tone or style…" : customToneBuffer
        toneTextLabel.textColor = customToneBuffer.isEmpty ? .placeholderText : .label
        toneTextLabel.font = .systemFont(ofSize: 13)
        toneTextLabel.adjustsFontSizeToFitWidth = true
        toneTextLabel.minimumScaleFactor = 0.75
        customToneDisplayLabel = toneTextLabel

        // ── Row 2: "NAME" label + name pill + action buttons ──────────
        let nameTag = makeFieldTag("NAME", active: false)

        let namePill = UIView()
        namePill.backgroundColor = pillBg
        namePill.layer.cornerRadius = 9
        namePill.layer.borderWidth = 1.5
        namePill.layer.borderColor = UIColor.clear.cgColor         // inactive

        let nameTextLabel = UILabel()
        nameTextLabel.text = "give it a name…"
        nameTextLabel.textColor = .placeholderText
        nameTextLabel.font = .systemFont(ofSize: 13)
        nameTextLabel.adjustsFontSizeToFitWidth = true
        nameTextLabel.minimumScaleFactor = 0.75
        customToneNameLabel = nameTextLabel

        // Tap desc pill → activate TONE field
        let descTap = UIButton(type: .system)
        descTap.addAction(UIAction { [weak self, weak descPill, weak namePill,
                                      weak toneTag, weak nameTag] _ in
            self?.customToneNaming = false
            descPill?.layer.borderColor = UIColor.systemBlue.cgColor
            namePill?.layer.borderColor = UIColor.clear.cgColor
            toneTag?.textColor = .systemBlue
            nameTag?.textColor = .tertiaryLabel
        }, for: .touchUpInside)

        // Tap name pill → activate NAME field
        let nameTap = UIButton(type: .system)
        nameTap.addAction(UIAction { [weak self, weak descPill, weak namePill,
                                      weak toneTag, weak nameTag] _ in
            self?.customToneNaming = true
            namePill?.layer.borderColor = UIColor.systemBlue.cgColor
            descPill?.layer.borderColor = UIColor.clear.cgColor
            nameTag?.textColor = .systemBlue
            toneTag?.textColor = .tertiaryLabel
        }, for: .touchUpInside)

        let sym  = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let sym2 = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)

        // ✓ Apply — use once, no save
        let applyBtn = UIButton(type: .system)
        applyBtn.setImage(UIImage(systemName: "checkmark.circle.fill", withConfiguration: sym2), for: .normal)
        applyBtn.tintColor = .systemBlue
        applyBtn.addAction(UIAction { [weak self] _ in
            guard let self, !self.customToneBuffer.isEmpty else { return }
            self.applyCustomTone(save: false)
        }, for: .touchUpInside)

        // 🔖 Save — persist to a slot then use
        let saveBtn = UIButton(type: .system)
        saveBtn.setImage(UIImage(systemName: "bookmark.fill", withConfiguration: sym), for: .normal)
        saveBtn.tintColor = .systemOrange
        saveBtn.addAction(UIAction { [weak self, weak toneTextLabel] _ in
            guard let self, !self.customToneBuffer.isEmpty else { return }
            guard KeyboardSettings.savedTones.count < 4 else {
                toneTextLabel?.text = "Max 4 saved — tap − on a tone to delete"
                toneTextLabel?.textColor = .systemRed
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak toneTextLabel, weak self] in
                    guard let self else { return }
                    toneTextLabel?.text = self.customToneBuffer.isEmpty
                        ? "describe your tone or style…" : self.customToneBuffer
                    toneTextLabel?.textColor = self.customToneBuffer.isEmpty ? .placeholderText : .label
                }
                return
            }
            self.applyCustomTone(save: true)
        }, for: .touchUpInside)

        // ── Layout: pill interiors ────────────────────────────────────
        for (label, tap, container) in [(toneTextLabel, descTap, descPill),
                                        (nameTextLabel, nameTap, namePill)] {
            label.translatesAutoresizingMaskIntoConstraints = false
            tap.translatesAutoresizingMaskIntoConstraints   = false
            container.addSubview(label)
            container.addSubview(tap)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                tap.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                tap.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                tap.topAnchor.constraint(equalTo: container.topAnchor),
                tap.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        // ── Layout: header ────────────────────────────────────────────
        let sep = UIView(); sep.backgroundColor = .separator
        [cancelBtn, toneTag, descPill, nameTag, namePill,
         applyBtn, saveBtn, sep].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            // × Cancel — left, aligned with row 1
            cancelBtn.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 8),
            cancelBtn.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            cancelBtn.widthAnchor.constraint(equalToConstant: 26),
            cancelBtn.heightAnchor.constraint(equalToConstant: 32),

            // Row 1: TONE tag + description pill (full width)
            toneTag.leadingAnchor.constraint(equalTo: cancelBtn.trailingAnchor, constant: 4),
            toneTag.centerYAnchor.constraint(equalTo: cancelBtn.centerYAnchor),
            toneTag.widthAnchor.constraint(equalToConstant: 38),
            descPill.leadingAnchor.constraint(equalTo: toneTag.trailingAnchor, constant: 4),
            descPill.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10),
            descPill.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            descPill.heightAnchor.constraint(equalToConstant: 32),

            // Row 2: NAME tag + name pill + Apply + Save
            nameTag.leadingAnchor.constraint(equalTo: toneTag.leadingAnchor),
            nameTag.centerYAnchor.constraint(equalTo: namePill.centerYAnchor),
            nameTag.widthAnchor.constraint(equalToConstant: 38),
            saveBtn.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10),
            saveBtn.topAnchor.constraint(equalTo: descPill.bottomAnchor, constant: 8),
            saveBtn.widthAnchor.constraint(equalToConstant: 28),
            saveBtn.heightAnchor.constraint(equalToConstant: 28),
            applyBtn.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -6),
            applyBtn.topAnchor.constraint(equalTo: descPill.bottomAnchor, constant: 8),
            applyBtn.widthAnchor.constraint(equalToConstant: 28),
            applyBtn.heightAnchor.constraint(equalToConstant: 28),
            namePill.leadingAnchor.constraint(equalTo: nameTag.trailingAnchor, constant: 4),
            namePill.trailingAnchor.constraint(equalTo: applyBtn.leadingAnchor, constant: -6),
            namePill.topAnchor.constraint(equalTo: descPill.bottomAnchor, constant: 8),
            namePill.heightAnchor.constraint(equalToConstant: 28),

            // Separator
            sep.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        keyboardStack.addArrangedSubview(headerView)
        keyboardStack.addArrangedSubview(makeLetterFastRow("qwertyuiop"))
        keyboardStack.addArrangedSubview(makeLetterFastRow("asdfghjkl", sideInset: 20))
        keyboardStack.addArrangedSubview(makeThirdLetterRow())
        keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "123"))

        // Blinking cursor — placeholder is always visible; only the | blinks at the end
        var cursorOn = true
        let descPlaceholder = "describe your tone or style…"
        let namePlaceholder = "give it a name…"
        customToneCursorTimer = Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { [weak self] _ in
            guard let self else { return }
            cursorOn.toggle()
            if self.customToneNaming {
                let t = self.customToneNameBuffer
                let base = t.isEmpty ? namePlaceholder : t
                self.customToneNameLabel?.text      = cursorOn ? base + "|" : base
                self.customToneNameLabel?.textColor = t.isEmpty ? .placeholderText : .label
            } else {
                let t = self.customToneBuffer
                let base = t.isEmpty ? descPlaceholder : t
                self.customToneDisplayLabel?.text      = cursorOn ? base + "|" : base
                self.customToneDisplayLabel?.textColor = t.isEmpty ? .placeholderText : .label
            }
        }
    }

    private func makeFieldTag(_ text: String, active: Bool) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 10, weight: .bold)
        l.textColor = active ? .systemBlue : .tertiaryLabel
        return l
    }

    private func applyCustomTone(save: Bool) {
        let inst = customToneBuffer
        if save {
            var tones = KeyboardSettings.savedTones
            let raw = customToneNameBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = raw.isEmpty ? "Custom \(tones.count + 1)" : raw
            tones.append(SavedTone(name: name, instruction: inst))
            KeyboardSettings.savedTones = tones
        }
        customToneBuffer = ""
        customToneNameBuffer = ""
        aiCustomInstruction = inst
        currentTone = .custom
        aiRefinedText = ""
        keyboardMode = .aiReview
        renderKeyboard()
        currentAIReviewView?.setContent(original: aiOriginalText, refined: "")
        runAIRefine(tone: .custom, customInstruction: inst)
    }

    private func makeTextRow(_ keys: [String]) -> FastKeyRow {
        let row = FastKeyRow(sideInset: 0, background: letterKeyBackground)
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true
        row.keyPreview = keyPreview
        row.previewContainer = view
        keys.forEach { key in
            row.addKey(base: key, display: key) { [weak self] in self?.insertUserText(key) }
        }
        return row
    }

    private func makeSymbolRow(cornerTitle: String, cornerAction: @escaping () -> Void) -> UIStackView {
        let row = makeRow()
        row.distribution = .fill

        let corner = makeSystemButton(title: cornerTitle)
        corner.widthAnchor.constraint(equalToConstant: 58).isActive = true
        addTapAction(to: corner, action: cornerAction)
        row.addArrangedSubview(corner)

        let keysRow = makeTextRow([".", ",", "?", "!", "'"])
        row.addArrangedSubview(keysRow)

        let delete = makeSystemButton(title: nil, imageName: "delete.left")
        delete.widthAnchor.constraint(equalToConstant: 58).isActive = true
        addDeleteAction(to: delete)
        row.addArrangedSubview(delete)

        return row
    }

    private func makeEmojiRow(_ emojis: [String]) -> UIStackView {
        let row = makeRow()
        emojis.forEach { emoji in
            let button = makeFlatEmojiButton(title: emoji)
            addCharacterAction(to: button) { [weak self] in
                self?.insertCharacter(emoji)
            }
            row.addArrangedSubview(button)
        }
        return row
    }

    private func makeEmojiScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.heightAnchor.constraint(equalToConstant: 154).isActive = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        emojiCategories.forEach { title, rows in
            let page = makeEmojiCategoryPage(title: title, rows: rows)
            stack.addArrangedSubview(page)
            emojiCategoryAnchors.append(page)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -4),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -8)
        ])

        emojiScrollView = scrollView
        return scrollView
    }

    private func makeEmojiCategoryPage(title: String, rows: [[String]]) -> UIStackView {
        let page = UIStackView()
        page.axis = .vertical
        page.spacing = 7

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        page.addArrangedSubview(titleLabel)

        rows.forEach { page.addArrangedSubview(makeEmojiRow($0)) }

        return page
    }

    private func makeThirdLetterRow() -> UIStackView {
        let row = makeRow()
        row.distribution = .fill

        let shift = makeSystemButton(title: nil, imageName: "shift")
        shift.widthAnchor.constraint(equalToConstant: 58).isActive = true
        shiftButton = shift
        addTapAction(to: shift) { [weak self] in
            guard let self else { return }
            let now = Date()
            if let last = self.lastShiftTapTime, now.timeIntervalSince(last) < 0.35 {
                self.capsLocked = true
                self.isShifted = true
                self.lastShiftTapTime = nil
            } else {
                if self.capsLocked {
                    self.capsLocked = false
                    self.isShifted = false
                } else {
                    self.isShifted.toggle()
                }
                self.lastShiftTapTime = now
            }
            self.refreshLetterCasing()
            self.updateShiftAppearance()
        }
        row.addArrangedSubview(shift)

        row.addArrangedSubview(makeLetterFastRow("zxcvbnm"))

        let delete = makeSystemButton(title: nil, imageName: "delete.left")
        delete.widthAnchor.constraint(equalToConstant: 58).isActive = true
        addDeleteAction(to: delete)
        row.addArrangedSubview(delete)

        updateShiftAppearance()

        return row
    }

    private func makeEmojiTabsRow() -> UIStackView {
        let row = makeRow()

        let abc = UIButton(type: .system)
        abc.setTitle("ABC", for: .normal)
        abc.setTitleColor(.label, for: .normal)
        abc.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        addTapAction(to: abc) { [weak self] in
            self?.keyboardMode = .letters
            self?.renderKeyboard()
        }
        row.addArrangedSubview(abc)

        ["clock", "face.smiling", "leaf", "fork.knife", "soccerball", "car"].enumerated().forEach { index, iconName in
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: iconName), for: .normal)
            button.tintColor = .secondaryLabel
            addTapAction(to: button) { [weak self] in
                self?.scrollToEmojiCategory(index)
            }
            row.addArrangedSubview(button)
        }

        let delete = UIButton(type: .system)
        delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
        delete.tintColor = .label
        addDeleteAction(to: delete)
        row.addArrangedSubview(delete)

        return row
    }

    private func scrollToEmojiCategory(_ index: Int) {
        guard let scrollView = emojiScrollView, index < emojiCategoryAnchors.count else { return }
        let anchor = emojiCategoryAnchors[index]
        let targetFrame = anchor.convert(anchor.bounds, to: scrollView)
        let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let offsetY = min(max(0, targetFrame.minY), maxOffsetY)
        scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)
    }

    private func makeRow() -> UIStackView {
        let row = KeyRowView()
        row.axis = .horizontal
        row.spacing = 5
        row.distribution = .fillEqually
        return row
    }

    private func makeSpacer(width: CGFloat) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false   // spacers must never swallow touches
        v.widthAnchor.constraint(equalToConstant: width).isActive = true
        return v
    }

    private func refreshLetterCasing() {
        let toUpper = isShifted || capsLocked
        fastLetterRows.forEach { $0.refreshCasing(toUpper: toUpper) }
    }

    private func updateShiftAppearance() {
        guard let shiftButton else { return }
        let imageName = capsLocked ? "capslock.fill" : (isShifted ? "shift.fill" : "shift")
        let symCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        shiftButton.setImage(UIImage(systemName: imageName, withConfiguration: symCfg), for: .normal)
        shiftButton.layer.backgroundColor = ((isShifted || capsLocked) ? letterKeyBackground : specialKeyBackground).cgColor
    }

    private func makeBox(
        langIcon: String,
        langTitle: String,
        actionIcon: String,
        actionTitle: String,
        showsChevron: Bool,
        langBtnWidth: CGFloat = 68
    ) -> (container: UIView, langBtn: UIButton, actionBtn: UIButton) {
        let box = UIView()
        box.backgroundColor = actionPillBackground
        box.layer.cornerRadius = 12
        box.layer.masksToBounds = true
        box.layer.borderWidth = 0.5
        box.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor

        // Language indicator (left) — secondary style
        let langBtn = UIButton(type: .system)
        let smallSym = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        langBtn.setImage(UIImage(systemName: langIcon, withConfiguration: smallSym), for: .normal)
        langBtn.setTitle(" \(langTitle)", for: .normal)
        langBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        langBtn.tintColor = .secondaryLabel
        langBtn.setTitleColor(.secondaryLabel, for: .normal)
        langBtn.translatesAutoresizingMaskIntoConstraints = false

        // Thin separator
        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        sep.translatesAutoresizingMaskIntoConstraints = false

        // Action button (right) — primary style
        let actionBtn = UIButton(type: .system)
        let actionSym = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        actionBtn.setImage(UIImage(systemName: actionIcon, withConfiguration: actionSym), for: .normal)
        actionBtn.setTitle(" \(actionTitle)", for: .normal)
        actionBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        actionBtn.tintColor = .label
        actionBtn.setTitleColor(.label, for: .normal)
        actionBtn.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(langBtn)
        box.addSubview(sep)
        box.addSubview(actionBtn)

        NSLayoutConstraint.activate([
            langBtn.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 4),
            langBtn.topAnchor.constraint(equalTo: box.topAnchor),
            langBtn.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            langBtn.widthAnchor.constraint(equalToConstant: langBtnWidth),

            sep.leadingAnchor.constraint(equalTo: langBtn.trailingAnchor),
            sep.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            sep.heightAnchor.constraint(equalTo: box.heightAnchor, multiplier: 0.55),
            sep.widthAnchor.constraint(equalToConstant: 0.5),

            actionBtn.leadingAnchor.constraint(equalTo: sep.trailingAnchor),
            actionBtn.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            actionBtn.topAnchor.constraint(equalTo: box.topAnchor),
            actionBtn.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])

        if showsChevron {
            let chevron = UIImageView()
            let chevSym = UIImage.SymbolConfiguration(pointSize: 7, weight: .bold)
            chevron.image = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: chevSym)
            chevron.tintColor = .tertiaryLabel
            chevron.isUserInteractionEnabled = false
            chevron.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(chevron)
            NSLayoutConstraint.activate([
                chevron.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
                chevron.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            ])
        }

        return (box, langBtn, actionBtn)
    }

    private func makeKeyButton(title: String, showsPreview: Bool = true) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.55
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.isExclusiveTouch = false
        button.layer.backgroundColor = letterKeyBackground.cgColor
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        if showsPreview {
            addKeyPreview(to: button)
        } else {
            addPressFeedback(to: button)
        }
        return button
    }

    private func makeSystemButton(title: String?, imageName: String? = nil) -> UIButton {
        let button = UIButton(type: .custom)
        if let title {
            button.setTitle(title, for: .normal)
            button.setTitleColor(.label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.7
        }
        if let imageName {
            let symCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            button.setImage(UIImage(systemName: imageName, withConfiguration: symCfg), for: .normal)
            button.tintColor = .label
        }
        button.layer.backgroundColor = specialKeyBackground.cgColor
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        addPressFeedback(to: button)
        return button
    }

    private func makeFlatEmojiButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28, weight: .regular)
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return button
    }

    private func addTapAction(to button: UIButton, action: @escaping () -> Void) {
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    private func addCharacterAction(to button: UIButton, action: @escaping () -> Void) {
        button.addAction(UIAction { _ in action() }, for: .touchDown)
    }

    private func addDeleteAction(to button: UIButton) {
        button.addAction(UIAction { [weak self] _ in
            self?.deleteCharacter()
            self?.startDeleteRepeat()
        }, for: .touchDown)
        button.addAction(UIAction { [weak self] _ in
            self?.stopDeleteRepeat()
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func startDeleteRepeat() {
        deleteTimer?.invalidate()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.deleteCharacter()
            }
        }
    }

    private func stopDeleteRepeat() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }

    private func addKeyPreview(to button: UIButton) {
        button.addAction(UIAction { [weak self, weak button] _ in
            guard let self, let button, let title = button.title(for: .normal), !title.isEmpty else { return }
            let frame = button.convert(button.bounds, to: self.view)
            self.keyPreview.show(character: title, above: frame, in: self.view)
        }, for: .touchDown)

        button.addAction(UIAction { [weak self] _ in
            self?.keyPreview.hide()
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func insertCharacter(_ text: String) {
        insertUserText(text)
    }

    private func deleteCharacter() {
        deleteUserText()
    }

    private func insertUserText(_ text: String) {
        if keyboardMode == .customToneInput {
            if customToneNaming {
                customToneNameBuffer += text
                customToneNameLabel?.textColor = .label
                customToneNameLabel?.text = customToneNameBuffer
            } else {
                customToneBuffer += text
                customToneDisplayLabel?.text = customToneBuffer
                updateCustomToneShift(after: text)
            }
            return
        }
        lastRewriteCharacterCount = nil
        textDocumentProxy.insertText(text)
    }

    private func deleteUserText() {
        if keyboardMode == .customToneInput {
            if customToneNaming {
                if !customToneNameBuffer.isEmpty { customToneNameBuffer.removeLast() }
                customToneNameLabel?.text = customToneNameBuffer
            } else {
                if !customToneBuffer.isEmpty { customToneBuffer.removeLast() }
                customToneDisplayLabel?.text = customToneBuffer
                updateCustomToneShift(after: nil)
            }
            return
        }
        lastRewriteCharacterCount = nil
        textDocumentProxy.deleteBackward()
    }

    // Auto-capitalize for the custom tone description field.
    // Pass the just-typed character, or nil for a deletion.
    private func updateCustomToneShift(after typed: String?) {
        guard !capsLocked else { return }
        let buf = customToneBuffer
        let atSentenceStart = buf.isEmpty
            || buf.hasSuffix(". ") || buf.hasSuffix("! ") || buf.hasSuffix("? ")
            || buf.hasSuffix(".\n") || buf.hasSuffix("!\n") || buf.hasSuffix("?\n")
        if atSentenceStart {
            if !isShifted { isShifted = true; refreshLetterCasing() }
        } else if let t = typed, t.rangeOfCharacter(from: .letters) != nil, isShifted {
            isShifted = false
            refreshLetterCasing()
        }
    }

    private func addPressFeedback(to button: UIButton) {
        button.addAction(UIAction { [weak button] _ in
            button?.alpha = 0.72
        }, for: .touchDown)
        button.addAction(UIAction { [weak button] _ in
            button?.alpha = 1
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func languageDisplayTitle() -> String {
        outputLanguage == "Auto" ? "Auto" : languageCode(for: outputLanguage)
    }

    private func translateLanguageDisplayTitle() -> String {
        languageCode(for: KeyboardSettings.translateLanguage)
    }

    private func updateLanguageButtonTitle() {
        let sym = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        languageButton?.setImage(UIImage(systemName: "globe", withConfiguration: sym), for: .normal)
        languageButton?.setTitle(" \(languageDisplayTitle())", for: .normal)
        languageButton?.menu = makeRewriteLanguageMenu()
    }

    private func updateTranslateLangButton() {
        let sym = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        translateLangButton?.setImage(UIImage(systemName: "arrow.right.circle.fill", withConfiguration: sym), for: .normal)
        translateLangButton?.setTitle(" \(translateLanguageDisplayTitle())", for: .normal)
        translateLangButton?.menu = makeTranslateLanguageMenu()
    }

    private func updateTranslateButton() {
        let sym = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        translateButton?.setImage(UIImage(systemName: "character.bubble.fill", withConfiguration: sym), for: .normal)
        translateButton?.setTitle(" Translate", for: .normal)
    }

    private func toneIconName(for mode: RewriteMode) -> String {
        switch mode {
        case .polish:       return "sparkles"
        case .warm:         return "heart.fill"
        case .professional: return "briefcase.fill"
        case .shorter:      return "scissors"
        case .translate:    return "character.bubble"
        case .grammar:      return "checkmark.circle"
        case .flirty:       return "face.smiling"
        case .street:       return "flame.fill"
        case .funny:        return "theatermasks"
        case .custom:       return "pencil"
        }
    }

    private func toneName(for mode: RewriteMode) -> String {
        switch mode {
        case .polish:       return "Refine"
        case .warm:         return "Warm"
        case .professional: return "Professional"
        case .shorter:      return "Short"
        case .translate:    return "Translate"
        case .grammar:      return "Grammar"
        case .flirty:       return "Flirty"
        case .street:       return "Vibe"
        case .funny:        return "Funny"
        case .custom:       return "Custom"
        }
    }

    private func updateToneButton() {
        let sym = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        toneButton?.setImage(UIImage(systemName: toneIconName(for: currentTone), withConfiguration: sym), for: .normal)
        toneButton?.setTitle(" \(toneName(for: currentTone))", for: .normal)
        toneButton?.menu = makeToneMenu()
    }

    private func makeToneMenu() -> UIMenu {
        let tones: [(RewriteMode, String, String)] = [
            (.polish,       "Refine",       "sparkles"),
            (.warm,         "Warm",         "heart.fill"),
            (.professional, "Professional", "briefcase.fill"),
            (.shorter,      "Short",        "scissors"),
        ]
        let actions = tones.map { mode, name, icon in
            UIAction(
                title: name,
                image: UIImage(systemName: icon),
                state: mode == currentTone ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                self.currentTone = mode
                self.updateToneButton()
                self.refineCurrentText(mode: mode)
            }
        }
        return UIMenu(title: "Choose Tone", children: actions)
    }

    private func languageCode(for language: String) -> String {
        let codes = [
            "English": "EN", "Spanish": "ES", "French": "FR", "German": "DE",
            "Italian": "IT", "Portuguese": "PT", "Dutch": "NL", "Swedish": "SV",
            "Norwegian": "NO", "Danish": "DA", "Finnish": "FI", "Icelandic": "IS",
            "Irish": "GA", "Welsh": "CY", "Polish": "PL", "Czech": "CS",
            "Slovak": "SK", "Hungarian": "HU", "Romanian": "RO", "Bulgarian": "BG",
            "Croatian": "HR", "Serbian": "SR", "Slovenian": "SL", "Greek": "EL",
            "Turkish": "TR", "Russian": "RU", "Ukrainian": "UK", "Hebrew": "HE",
            "Arabic": "AR", "Persian": "FA", "Urdu": "UR", "Hindi": "HI",
            "Bengali": "BN", "Punjabi": "PA", "Gujarati": "GU", "Tamil": "TA",
            "Telugu": "TE", "Malayalam": "ML", "Kannada": "KN", "Marathi": "MR",
            "Nepali": "NE", "Sinhala": "SI", "Chinese Simplified": "ZH-CN",
            "Chinese Traditional": "ZH-TW", "Japanese": "JA", "Korean": "KO",
            "Vietnamese": "VI", "Thai": "TH", "Indonesian": "ID", "Malay": "MS",
            "Filipino": "FIL", "Swahili": "SW", "Amharic": "AM", "Yoruba": "YO",
            "Igbo": "IG", "Hausa": "HA", "Zulu": "ZU", "Afrikaans": "AF",
            "Albanian": "SQ", "Armenian": "HY", "Azerbaijani": "AZ", "Basque": "EU",
            "Catalan": "CA", "Estonian": "ET", "Georgian": "KA", "Kazakh": "KK",
            "Latvian": "LV", "Lithuanian": "LT", "Macedonian": "MK",
            "Mongolian": "MN", "Pashto": "PS", "Somali": "SO", "Tagalog": "TL"
        ]
        return codes[language] ?? String(language.prefix(2)).uppercased()
    }

    private func makeRewriteLanguageMenu() -> UIMenu {
        let actions = languages.map { language in
            UIAction(title: language, state: language == outputLanguage ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.outputLanguage = language
                KeyboardSettings.sharedDefaults.set(language, forKey: KeyboardSettings.languageKey)
                self.updateLanguageButtonTitle()
                self.showStatus(language == "Auto" ? "Rewrite: Auto" : "Rewrite → \(self.languageCode(for: language))")
                let code = language == "Auto" ? "Auto" : self.languageCode(for: language)
                self.currentAIReviewView?.updateSourceLang(code: code)
            }
        }
        return UIMenu(title: "Rewrite Language", children: actions)
    }

    private func makeTranslateLanguageMenu() -> UIMenu {
        let current = KeyboardSettings.translateLanguage
        let actions = languages.filter { $0 != "Auto" }.map { language in
            UIAction(title: language, state: language == current ? .on : .off) { [weak self] _ in
                guard let self else { return }
                KeyboardSettings.sharedDefaults.set(language, forKey: KeyboardSettings.translateLanguageKey)
                self.updateTranslateLangButton()
                self.showTranslateStatus("→ \(self.languageCode(for: language))")
                // Keep AI review voice button in sync and clear stale translation cache
                let code = self.languageCode(for: language)
                self.currentAIReviewView?.updateTargetLang(code: code)
                self.aiTranslatedText = nil
                self.stopSpeaking()
            }
        }
        return UIMenu(title: "Translate To", children: actions)
    }

    private func refineCurrentText(mode: RewriteMode) {
        guard hasFullAccess else {
            showStatus("Enable Full Access")
            return
        }
        guard KeyboardSettings.isSubscriptionActive else {
            showStatus("Open RefineKeyboard app to subscribe")
            return
        }

        let selected = textDocumentProxy.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let usingSelection = !selected.isEmpty
        let contextBeforeInput = usingSelection ? "" : (textDocumentProxy.documentContextBeforeInput ?? "")
        let contextAfterInput  = usingSelection ? "" : (textDocumentProxy.documentContextAfterInput ?? "")
        let text = usingSelection ? selected : (contextBeforeInput + contextAfterInput).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            showStatus("Type or select text")
            return
        }

        showStatus("Refining...")

        Task { [weak self] in
            guard let self else { return }
            do {
                let refined = try await client.rewrite(text: text, mode: mode, language: outputLanguage)
                await MainActor.run {
                    if refined == text {
                        self.showStatus("No change")
                    } else if usingSelection {
                        // insertText replaces the active selection on iOS
                        self.textDocumentProxy.insertText(refined)
                        self.lastRewriteCharacterCount = nil
                        self.showStatus("Inserted")
                    } else {
                        self.replaceCurrentDraft(
                            contextBeforeInput: contextBeforeInput,
                            contextAfterInput: contextAfterInput,
                            refined: refined
                        )
                        self.showStatus("Inserted")
                    }
                }
            } catch {
                await MainActor.run {
                    self.showStatus(self.message(for: error))
                }
            }
        }
    }

    private func translateSelectedText() {
        guard hasFullAccess else {
            showTranslateStatus("Enable Full Access")
            return
        }
        guard KeyboardSettings.isSubscriptionActive else {
            showTranslateStatus("Subscribe in app")
            return
        }

        let selected = textDocumentProxy.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let source: String
        if !selected.isEmpty {
            source = selected
        } else {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            let after  = textDocumentProxy.documentContextAfterInput ?? ""
            let full = (before + after).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !full.isEmpty else {
                showTranslateStatus("Type or select text")
                return
            }
            source = full
        }

        let targetLanguage = KeyboardSettings.translateLanguage
        translateButton?.setTitle(" Translating...", for: .normal)
        translateButton?.setImage(nil, for: .normal)
        bannerDismissTask?.cancel()
        translationBanner.hide(animated: false)

        Task { [weak self] in
            guard let self else { return }
            do {
                let translated = try await client.rewrite(text: source, mode: .translate, language: targetLanguage)
                await MainActor.run {
                    self.lastTranslation = translated
                    self.updateTranslateButton()
                    self.showTranslation(translated, language: targetLanguage)
                }
            } catch {
                await MainActor.run {
                    self.showTranslateStatus(self.message(for: error))
                }
            }
        }
    }

    private func showTranslation(_ text: String, language: String) {
        translationBanner.show(translation: text, language: language)
    }

    private func showStatus(_ message: String) {
        statusTask?.cancel()
        updateTranslateButton()
        languageButton?.setTitle(message, for: .normal)
        languageButton?.setImage(nil, for: .normal)
        statusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.updateLanguageButtonTitle() }
        }
    }

    private func showTranslateStatus(_ message: String) {
        statusTask?.cancel()
        updateLanguageButtonTitle()
        translateButton?.setTitle(message, for: .normal)
        translateButton?.setImage(nil, for: .normal)
        statusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.updateTranslateButton() }
        }
    }

    private func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet access"
            case .timedOut:
                return "Service timed out"
            default:
                return "Network error"
            }
        }

        return (error as? LocalizedError)?.errorDescription ?? "Could not refine"
    }

    private func replaceCurrentDraft(contextBeforeInput: String, contextAfterInput: String, refined: String) {
        guard !refined.isEmpty else { return }
        if !contextAfterInput.isEmpty {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: contextAfterInput.count)
        }
        let availableDraftCount = contextBeforeInput.count + contextAfterInput.count
        let deletionCount = max(availableDraftCount, lastRewriteCharacterCount ?? 0)
        (0..<deletionCount).forEach { _ in
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(refined)
        lastRewriteCharacterCount = refined.count
    }
}


// Custom key row that renders keys as UILabels and routes all touches directly in touchesBegan,
// skipping UIButton's internal state machine entirely. This eliminates per-key UIButton overhead
// and fires haptic + character insertion at the very start of the touch event.
private final class FastKeyRow: UIView {
    struct Key {
        var frame: CGRect = .zero
        let label: UILabel
        let baseChar: String     // base (lowercase/original) form used for casing refresh
        let action: () -> Void
    }

    var keys: [Key] = []
    weak var keyPreview: KeyPreviewView?
    weak var previewContainer: UIView?

    private let sideInset: CGFloat
    private let keyBackground: UIColor
    private let keySpacing: CGFloat = 5

    init(sideInset: CGFloat = 0, background: UIColor) {
        self.sideInset = sideInset
        self.keyBackground = background
        super.init(frame: .zero)
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func addKey(
        base: String,
        display: String,
        font: UIFont = .systemFont(ofSize: 24, weight: .regular),
        action: @escaping () -> Void
    ) {
        let label = UILabel()
        label.text = display
        label.textAlignment = .center
        label.font = font
        label.textColor = .label
        label.layer.backgroundColor = keyBackground.cgColor
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = false
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.3
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 0
        label.isUserInteractionEnabled = false
        addSubview(label)
        keys.append(Key(label: label, baseChar: base, action: action))
    }

    func refreshCasing(toUpper: Bool) {
        for i in keys.indices {
            let updated = toUpper ? keys[i].baseChar.uppercased() : keys[i].baseChar.lowercased()
            if keys[i].label.text != updated { keys[i].label.text = updated }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !keys.isEmpty else { return }
        let n = CGFloat(keys.count)
        let available = bounds.width - sideInset * 2
        let keyW = (available - keySpacing * (n - 1)) / n
        for i in keys.indices {
            let x = sideInset + CGFloat(i) * (keyW + keySpacing)
            let f = CGRect(x: x, y: 0, width: keyW, height: bounds.height)
            keys[i].frame = f
            keys[i].label.frame = f
        }
    }

    // Expand the touch area 4pt above and below so touches in inter-row gaps register.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: 0, dy: -4).contains(point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pt = touches.first?.location(in: self), !keys.isEmpty else { return }
        let key = nearest(to: pt)
        // Preview fires first for immediate visual feedback before the XPC insertText call.
        if let preview = keyPreview, let container = previewContainer {
            preview.show(character: key.label.text ?? "", above: convert(key.frame, to: container), in: container)
        }
        key.action()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { keyPreview?.hide() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { keyPreview?.hide() }

    private func nearest(to pt: CGPoint) -> Key {
        keys.min { abs($0.frame.midX - pt.x) < abs($1.frame.midX - pt.x) } ?? keys[0]
    }
}

// UIStackView subclass that routes touches landing in inter-key gaps to the nearest key.
// Used for rows that mix UIButtons (shift, delete) with a FastKeyRow.
private final class KeyRowView: UIStackView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        if let hit = super.hitTest(point, with: event) { return hit }
        guard bounds.insetBy(dx: 0, dy: -8).contains(point) else { return nil }
        return arrangedSubviews
            .compactMap { $0 as? UIButton }
            .filter { !$0.isHidden && $0.isUserInteractionEnabled }
            .min { abs($0.frame.midX - point.x) < abs($1.frame.midX - point.x) }
    }
}

extension KeyboardViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        currentSpeechTarget = nil
        audioPlayer = nil
        currentAIReviewView?.setPlayingEN(false)
        currentAIReviewView?.setPlayingTarget(false)
    }
}

final class AIReviewView: UIView {
    var onToneChange:        ((RewriteMode, String) -> Void)?
    var onInsert:            (() -> Void)?
    var onPlayEN:            (() -> Void)?
    var onPlayTarget:        (() -> Void)?
    var onBack:              (() -> Void)?
    var onCustomToneOpen:    (() -> Void)?
    var onSavedToneSelected: ((String) -> Void)?

    var currentTone: RewriteMode = .polish { didSet { updateToneButtons() } }
    var toneHighlightEnabled: Bool = true { didSet { updateToneButtons() } }

    private let diffTextView     = UITextView()
    private let loadingLabel     = UILabel()
    private let playENBtn        = UIButton()
    private let playTargetBtn    = UIButton()
    private let insertBtn        = UIButton(type: .system)
    private let customBtn      = UIButton(type: .system)
    private let savedToneRow   = UIStackView()
    private var savedToneRowH: NSLayoutConstraint?
    private var toneButtonMap: [RewriteMode: UIButton] = [:]
    private(set) var sourceLangCode: String
    private(set) var targetLangCode: String

    init(pillBackground: UIColor, sourceLangCode: String, targetLangCode: String) {
        self.sourceLangCode = sourceLangCode
        self.targetLangCode = targetLangCode
        super.init(frame: .zero)
        backgroundColor = .clear

        // ── AI output text view (no label above it) ──────────────────
        diffTextView.isEditable = false
        diffTextView.isScrollEnabled = true
        diffTextView.backgroundColor = pillBackground
        diffTextView.layer.cornerRadius = 10
        diffTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        diffTextView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(diffTextView)

        loadingLabel.text = "AI is thinking…"
        loadingLabel.font = .systemFont(ofSize: 13)
        loadingLabel.textColor = .secondaryLabel
        loadingLabel.textAlignment = .center
        loadingLabel.isHidden = true
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadingLabel)

        // ── Tone rows: row1 = Grammar | Refine | Warm | Pro ─────────
        //              row2 = Short | Flirty | Street | Funny
        let row1Tones: [(RewriteMode, String)] = [
            (.grammar, "✅ Grammar"), (.polish, "✨ Refine"),
            (.warm, "💛 Warm"),       (.professional, "💼 Pro")
        ]
        let row2Tones: [(RewriteMode, String)] = [
            (.shorter, "✂️ Short"), (.flirty, "😍 Flirty"),
            (.street, "🔥 Vibe"),   (.funny, "😂 Funny")
        ]

        func makeToneRow(_ items: [(RewriteMode, String)]) -> UIStackView {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 5
            row.distribution = .fillEqually
            row.translatesAutoresizingMaskIntoConstraints = false
            for (mode, title) in items {
                let btn = UIButton(type: .custom)
                btn.setTitle(title, for: .normal)
                btn.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
                btn.titleLabel?.adjustsFontSizeToFitWidth = true
                btn.titleLabel?.minimumScaleFactor = 0.75
                btn.layer.cornerRadius = 7
                btn.layer.masksToBounds = true
                btn.addAction(UIAction { [weak self] _ in
                    guard let self else { return }
                    self.currentTone = mode
                    self.onToneChange?(mode, "")
                }, for: .touchUpInside)
                toneButtonMap[mode] = btn
                row.addArrangedSubview(btn)
            }
            return row
        }

        let toneRow1 = makeToneRow(row1Tones)
        let toneRow2 = makeToneRow(row2Tones)
        addSubview(toneRow1)
        addSubview(toneRow2)

        // ── Custom tone button (opens keyboard input) ────────────────
        let plusSym = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        customBtn.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: plusSym), for: .normal)
        customBtn.setTitle("  Custom Tone", for: .normal)
        customBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        customBtn.tintColor = .secondaryLabel
        customBtn.setTitleColor(.secondaryLabel, for: .normal)
        customBtn.backgroundColor = UIColor.secondarySystemFill
        customBtn.layer.cornerRadius = 7
        customBtn.layer.masksToBounds = true
        customBtn.translatesAutoresizingMaskIntoConstraints = false
        customBtn.addAction(UIAction { [weak self] _ in
            self?.currentTone = .custom
            self?.onCustomToneOpen?()
        }, for: .touchUpInside)
        addSubview(customBtn)

        // ── Saved tones row (up to 4 equal-width chips, between toneRow2 and customBtn) ──
        savedToneRow.axis = .horizontal
        savedToneRow.spacing = 5
        savedToneRow.distribution = .fillEqually
        savedToneRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(savedToneRow)
        let sh = savedToneRow.heightAnchor.constraint(equalToConstant: 0)
        savedToneRowH = sh

        // ── Voice buttons ─────────────────────────────────────────────
        configureVoiceBtn(playENBtn,     title: "▶  \(sourceLangCode)", color: .systemBlue)
        configureVoiceBtn(playTargetBtn, title: "▶  \(targetLangCode)", color: .systemPurple)
        playENBtn.addAction(UIAction     { [weak self] _ in self?.onPlayEN?()     }, for: .touchUpInside)
        playTargetBtn.addAction(UIAction { [weak self] _ in self?.onPlayTarget?() }, for: .touchUpInside)

        // ── Back (← Keys) ─────────────────────────────────────────────
        let backBtn = UIButton(type: .system)
        let chev = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: chev), for: .normal)
        backBtn.setTitle(" Keys", for: .normal)
        backBtn.titleLabel?.font = .systemFont(ofSize: 12)
        backBtn.tintColor = .secondaryLabel
        backBtn.setTitleColor(.secondaryLabel, for: .normal)
        backBtn.addAction(UIAction { [weak self] _ in self?.onBack?() }, for: .touchUpInside)

        // ── Insert button (green pill, bold) ──────────────────────────
        var insCfg = UIButton.Configuration.filled()
        insCfg.baseBackgroundColor = .systemGreen
        insCfg.baseForegroundColor = .white
        insCfg.image = UIImage(systemName: "checkmark.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        insCfg.imagePadding = 5
        insCfg.title = "Insert"
        insCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = UIFont.systemFont(ofSize: 13, weight: .bold); return a
        }
        insCfg.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
        insCfg.cornerStyle = .capsule
        insertBtn.configuration = insCfg
        insertBtn.configurationUpdateHandler = { btn in
            var c = btn.configuration
            c?.baseBackgroundColor = btn.isEnabled
                ? .systemGreen : UIColor.systemGreen.withAlphaComponent(0.30)
            btn.configuration = c
        }
        insertBtn.isEnabled = false
        insertBtn.addAction(UIAction { [weak self] _ in self?.onInsert?() }, for: .touchUpInside)

        // ── Bottom bar: [← Keys]  [▶ EN]  [▶ FA]  [✓ Insert] ─────────
        // Use a plain UIView with explicit constraints so each button sits exactly where it should.
        let bottomBar = UIView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomBar)
        [backBtn, playENBtn, playTargetBtn, insertBtn].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            bottomBar.addSubview($0)
        }
        NSLayoutConstraint.activate([
            // Back: left edge
            backBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            backBtn.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            // Insert: right edge
            insertBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            insertBtn.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            // Voice buttons: equal-width, fill the middle space
            playENBtn.leadingAnchor.constraint(equalTo: backBtn.trailingAnchor, constant: 8),
            playENBtn.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            playENBtn.heightAnchor.constraint(equalTo: bottomBar.heightAnchor),
            playTargetBtn.leadingAnchor.constraint(equalTo: playENBtn.trailingAnchor, constant: 6),
            playTargetBtn.trailingAnchor.constraint(equalTo: insertBtn.leadingAnchor, constant: -8),
            playTargetBtn.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            playTargetBtn.heightAnchor.constraint(equalTo: bottomBar.heightAnchor),
            playENBtn.widthAnchor.constraint(equalTo: playTargetBtn.widthAnchor),
        ])

        updateToneButtons()

        // ── Layout ───────────────────────────────────────────────────
        NSLayoutConstraint.activate([
            diffTextView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            diffTextView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            diffTextView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            diffTextView.heightAnchor.constraint(equalToConstant: 104),

            loadingLabel.centerXAnchor.constraint(equalTo: diffTextView.centerXAnchor),
            loadingLabel.centerYAnchor.constraint(equalTo: diffTextView.centerYAnchor),

            toneRow1.topAnchor.constraint(equalTo: diffTextView.bottomAnchor, constant: 6),
            toneRow1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            toneRow1.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            toneRow1.heightAnchor.constraint(equalToConstant: 26),

            toneRow2.topAnchor.constraint(equalTo: toneRow1.bottomAnchor, constant: 5),
            toneRow2.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            toneRow2.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            toneRow2.heightAnchor.constraint(equalToConstant: 26),

            savedToneRow.topAnchor.constraint(equalTo: toneRow2.bottomAnchor, constant: 5),
            savedToneRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            savedToneRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            sh,

            customBtn.topAnchor.constraint(equalTo: savedToneRow.bottomAnchor, constant: 5),
            customBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            customBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            customBtn.heightAnchor.constraint(equalToConstant: 26),

            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            bottomBar.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func setContent(original: String, refined: String) {
        if refined.isEmpty {
            loadingLabel.text = "AI is thinking…"; loadingLabel.isHidden = false
            diffTextView.attributedText = nil
            setActionsEnabled(false)
        } else {
            toneHighlightEnabled = true
            loadingLabel.isHidden = true
            diffTextView.attributedText = buildDiff(from: original, to: refined)
            setActionsEnabled(true)
        }
    }

    func showOriginalText(_ text: String) {
        loadingLabel.isHidden = true
        let attrs = NSMutableAttributedString(string: text)
        let range = NSRange(text.startIndex..., in: text)
        attrs.addAttributes([
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.label
        ], range: range)
        diffTextView.attributedText = attrs
        toneHighlightEnabled = false
        insertBtn.isEnabled = true
        playENBtn.isEnabled = true
        playTargetBtn.isEnabled = true
    }

    func setLoading(_ loading: Bool) {
        loadingLabel.text = "AI is thinking…"; loadingLabel.isHidden = !loading
        if loading { diffTextView.attributedText = nil; setActionsEnabled(false) }
    }

    func showError(_ message: String) {
        loadingLabel.text = message; loadingLabel.isHidden = false
        diffTextView.attributedText = nil; setActionsEnabled(false)
    }

    func setPlayingEN(_ playing: Bool) {
        playENBtn.setTitle(playing ? "⏸  \(sourceLangCode)" : "▶  \(sourceLangCode)", for: .normal)
        playENBtn.alpha = playing ? 0.7 : 1.0
    }

    func setPlayingTarget(_ playing: Bool) {
        playTargetBtn.setTitle(playing ? "⏸  \(targetLangCode)" : "▶  \(targetLangCode)", for: .normal)
        playTargetBtn.alpha = playing ? 0.7 : 1.0
    }

    func setTargetLoading(_ loading: Bool) {
        playTargetBtn.isEnabled = !loading
        playTargetBtn.alpha = loading ? 0.4 : 1.0
    }

    func updateTargetLang(code: String) {
        targetLangCode = code
        playTargetBtn.setTitle("▶  \(code)", for: .normal)
    }

    func updateSourceLang(code: String) {
        sourceLangCode = code
        playENBtn.setTitle("▶  \(code)", for: .normal)
    }

    func updateCustomToneLabel(_ instruction: String) {
        // Title stays as "+ Custom Tone"; only update the active tone highlight.
        currentTone = .custom
    }

    func reloadSavedTones() {
        savedToneRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        savedToneRowH?.constant = 26
        let tones = KeyboardSettings.savedTones

        for slot in 0..<4 {
            let container = UIView()
            container.layer.cornerRadius = 7
            container.layer.masksToBounds = true
            container.translatesAutoresizingMaskIntoConstraints = false

            if slot < tones.count {
                // ── Saved tone chip with "−" delete ──────────────────
                let tone = tones[slot]
                container.layer.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.13).cgColor

                let nameLabel = UILabel()
                nameLabel.text = tone.name
                nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
                nameLabel.textColor = .systemPurple
                nameLabel.adjustsFontSizeToFitWidth = true
                nameLabel.minimumScaleFactor = 0.7
                nameLabel.translatesAutoresizingMaskIntoConstraints = false

                let minusBtn = UIButton(type: .system)
                minusBtn.setTitle("−", for: .normal)
                minusBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
                minusBtn.setTitleColor(UIColor.systemPurple.withAlphaComponent(0.6), for: .normal)
                minusBtn.translatesAutoresizingMaskIntoConstraints = false
                let capturedSlot = slot
                minusBtn.addAction(UIAction { [weak self] _ in
                    var saved = KeyboardSettings.savedTones
                    guard capturedSlot < saved.count else { return }
                    saved.remove(at: capturedSlot)
                    KeyboardSettings.savedTones = saved
                    self?.reloadSavedTones()
                }, for: .touchUpInside)

                let tapBtn = UIButton(type: .system)
                tapBtn.translatesAutoresizingMaskIntoConstraints = false
                let inst = tone.instruction
                tapBtn.addAction(UIAction { [weak self] _ in
                    self?.onSavedToneSelected?(inst)
                }, for: .touchUpInside)

                nameLabel.textAlignment = .center

                [nameLabel, minusBtn, tapBtn].forEach { container.addSubview($0) }
                NSLayoutConstraint.activate([
                    // "−" pinned to far left
                    minusBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                    minusBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    minusBtn.widthAnchor.constraint(equalToConstant: 16),
                    // Name centered in the remaining space
                    nameLabel.leadingAnchor.constraint(equalTo: minusBtn.trailingAnchor, constant: 4),
                    nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                    nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    // Tap area covers the name region
                    tapBtn.leadingAnchor.constraint(equalTo: minusBtn.trailingAnchor),
                    tapBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    tapBtn.topAnchor.constraint(equalTo: container.topAnchor),
                    tapBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            } else {
                // ── Empty placeholder slot ────────────────────────────
                container.layer.backgroundColor = UIColor.secondarySystemFill.cgColor

                let placeholderLabel = UILabel()
                placeholderLabel.text = "Custom \(slot + 1)"
                placeholderLabel.font = .systemFont(ofSize: 11, weight: .medium)
                placeholderLabel.textColor = .tertiaryLabel
                placeholderLabel.textAlignment = .center
                placeholderLabel.adjustsFontSizeToFitWidth = true
                placeholderLabel.minimumScaleFactor = 0.7
                placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

                let tapBtn = UIButton(type: .system)
                tapBtn.translatesAutoresizingMaskIntoConstraints = false
                tapBtn.addAction(UIAction { [weak self] _ in
                    self?.onCustomToneOpen?()
                }, for: .touchUpInside)

                [placeholderLabel, tapBtn].forEach { container.addSubview($0) }
                NSLayoutConstraint.activate([
                    placeholderLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                    placeholderLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                    placeholderLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    tapBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    tapBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    tapBtn.topAnchor.constraint(equalTo: container.topAnchor),
                    tapBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            }

            savedToneRow.addArrangedSubview(container)
        }
    }

    // MARK: - Private helpers

    private func setActionsEnabled(_ on: Bool) {
        insertBtn.isEnabled = on
        playENBtn.isEnabled = on
        playTargetBtn.isEnabled = on
    }

    private func configureVoiceBtn(_ btn: UIButton, title: String, color: UIColor) {
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        btn.setTitleColor(color, for: .normal)
        btn.backgroundColor = color.withAlphaComponent(0.12)
        btn.layer.cornerRadius = 6
        btn.layer.masksToBounds = true
        btn.isEnabled = false
        btn.translatesAutoresizingMaskIntoConstraints = false
    }

    private func updateToneButtons() {
        for (mode, btn) in toneButtonMap {
            let on = toneHighlightEnabled && mode == currentTone
            btn.layer.backgroundColor = on
                ? UIColor.systemBlue.withAlphaComponent(0.18).cgColor
                : UIColor.secondarySystemFill.cgColor
            btn.setTitleColor(on ? .systemBlue : .secondaryLabel, for: .normal)
        }
        let customOn = toneHighlightEnabled && currentTone == .custom
        customBtn.backgroundColor = customOn
            ? UIColor.systemBlue.withAlphaComponent(0.14)
            : UIColor.secondarySystemFill
        customBtn.tintColor  = customOn ? .systemBlue : .secondaryLabel
        customBtn.setTitleColor(customOn ? .systemBlue : .secondaryLabel, for: .normal)
    }

    // MARK: - Word-level LCS diff

    private func buildDiff(from original: String, to refined: String) -> NSAttributedString {
        let a = original.components(separatedBy: " ")
        let b = refined.components(separatedBy: " ")
        let ops = lcsWordDiff(a, b)
        let base: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14)]
        let result = NSMutableAttributedString()
        for (i, op) in ops.enumerated() {
            let sp = i < ops.count - 1 ? " " : ""
            switch op {
            case .equal(let w):
                result.append(NSAttributedString(string: w + sp, attributes: base))
            case .insert(let w):
                var a = base; a[.foregroundColor] = UIColor.systemGreen
                a[.backgroundColor] = UIColor.systemGreen.withAlphaComponent(0.15)
                result.append(NSAttributedString(string: w + sp, attributes: a))
            case .delete(let w):
                var a = base; a[.foregroundColor] = UIColor.systemRed.withAlphaComponent(0.75)
                a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                a[.strikethroughColor] = UIColor.systemRed
                result.append(NSAttributedString(string: w + sp, attributes: a))
            }
        }
        return result
    }

    private enum Op { case equal(String), insert(String), delete(String) }

    private func lcsWordDiff(_ a: [String], _ b: [String]) -> [Op] {
        let m = a.count, n = b.count
        if m == 0 { return b.map { .insert($0) } }
        if n == 0 { return a.map { .delete($0) } }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m { for j in 1...n {
            dp[i][j] = a[i-1] == b[j-1] ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
        }}
        var ops: [Op] = []; var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0, j > 0, a[i-1] == b[j-1] { ops.append(.equal(a[i-1])); i -= 1; j -= 1 }
            else if j > 0, (i == 0 || dp[i][j-1] >= dp[i-1][j]) { ops.append(.insert(b[j-1])); j -= 1 }
            else { ops.append(.delete(a[i-1])); i -= 1 }
        }
        return ops.reversed()
    }
}

final class TranslationBannerView: UIView {
    var onTap: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let headerLabel = UILabel()
    private let bodyLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
        alpha = 0

        backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 0.95)
        layer.cornerRadius = 12
        layer.masksToBounds = true

        headerLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        headerLabel.textColor = UIColor(white: 1, alpha: 0.55)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        bodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = .white
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let copyHint = UILabel()
        copyHint.text = "Tap to copy"
        copyHint.font = .systemFont(ofSize: 11, weight: .regular)
        copyHint.textColor = UIColor(white: 1, alpha: 0.4)
        copyHint.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [headerLabel, bodyLabel, copyHint])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // Close (×) button — top-right corner
        let xSym = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: xSym), for: .normal)
        closeButton.tintColor = UIColor(white: 1, alpha: 0.55)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addAction(UIAction { [weak self] _ in self?.onDismiss?() }, for: .touchUpInside)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        addGestureRecognizer(tapGR)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(translation: String, language: String) {
        headerLabel.text = "TRANSLATION → \(language.uppercased())"
        bodyLabel.text = translation
        isHidden = false
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    func hide(animated: Bool = true) {
        guard !isHidden else { return }
        if animated {
            UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
                self.isHidden = true
            }
        } else {
            alpha = 0
            isHidden = true
        }
    }

    @objc private func tapped(_ gr: UITapGestureRecognizer) {
        // Let the close button handle its own tap
        guard !closeButton.frame.contains(gr.location(in: self)) else { return }
        onTap?()
    }
}
