import UIKit
import AVFoundation

final class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }

    private enum KeyboardMode {
        case letters
        case numbers
        case symbols
        case emoji
        case aiReview
        case customToneInput
    }

    private enum CustomToneKeyboardPage {
        case letters
        case numbers
        case symbols
        case emoji
    }

    private let client = RewriteClient()
    private var warmupTask: URLSessionDataTask?
    private var textOperationTask: Task<Void, Never>?
    private var textOperationGeneration = 0
    private var outputLanguage = KeyboardSettings.rewriteLanguage
    private var languageButton: UIButton?
    private var statusTask: Task<Void, Never>?
    private var deleteTimer: Timer?
    private let keyboardStack = UIStackView()
    private var keyboardHeightConstraint: NSLayoutConstraint?
    private var fastLetterRows: [FastKeyRow] = []
    private var shiftButton: UIButton?
    private var emojiCollectionView: UICollectionView?
    private var emojiCategoryButtons: [UIButton] = []
    private var isShifted = true
    private var capsLocked = false
    private var lastShiftTapTime: Date?
    private var shiftSyncGeneration = 0
    private var keyboardMode: KeyboardMode = .letters
    private let keyPreview = KeyPreviewView()
    private let translationBanner = TranslationBannerView()
    private var bannerDismissTask: Task<Void, Never>?
    private var lastTranslation: String?
    private weak var aiButton: UIButton?
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
    private var customToneCursorOffset = 0
    private var customToneNameCursorOffset = 0
    private var customToneNaming = false
    private var customToneKeyboardPage: CustomToneKeyboardPage = .letters
    private weak var customToneDisplayField: CustomToneTextFieldView?
    private weak var customToneNameField: CustomToneTextFieldView?
    private var customToneCursorTimer: Timer?
    private enum SpeechTarget { case english, target }
    private var currentSpeechTarget: SpeechTarget? = nil
    private var audioPlayer: AVAudioPlayer?
    private var speakTask: Task<Void, Never>?
    private var speechTranslationTask: Task<Void, Never>?
    private weak var currentAIReviewView: AIReviewView?
    private var translateLangButton: UIButton?
    private var translateButton: UIButton?
    private var keyboardRootView: UIStackView?
    private var isTextOperationInProgress = false
    private var fullTextCaptureGeneration = 0
    private var isCapturingFullText = false

    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var keyboardNormalHeight: CGFloat  { isIPad ? 330 : 268 }
    private var keyboardAIHeight: CGFloat      { isIPad ? 460 : 340 }
    private var keyboardToneHeight: CGFloat    { isIPad ? 400 : 298 }
    private var keyRowHeight: CGFloat          { isIPad ? 60  : 45  }
    private var actionRowHeight: CGFloat       { isIPad ? 46  : 38  }
    private var buttonHeight: CGFloat          { isIPad ? 56  : 45  }
    private var letterFontSize: CGFloat        { isIPad ? 30  : 26  }
    private var sideButtonWidth: CGFloat       { isIPad ? 72  : 47  }
    private var letterSideButtonWidth: CGFloat { isIPad ? 72  : 49  }

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

    private var emojiCategories: [(String, [[String]])] = [
        ("FREQUENTLY USED", [
            ["😁", "💕", "❤️", "😊", "✌️", "😎", "👍", "🎉"],
            ["😍", "😭", "😉", "🎵", "😂", "🌞", "🙁", "😔"],
            ["☺️", "👀", "💅", "🙏", "👌", "😏", "🤷", "😐"]
        ]),
        ("SMILEYS & PEOPLE", [
            ["😀", "🥹", "☺️", "😃", "😅", "😊", "😄", "😂"],
            ["😇", "😆", "🤣", "🙂", "😉", "😍", "😘", "😜"],
            ["🤔", "🫡", "🫢", "🫣", "🤭", "🤫", "🤪", "🤩"],
            ["😬", "🙄", "😴", "😢", "😭", "😡", "🤬", "🥶"],
            ["👋", "🤚", "🖐️", "✋", "🖖", "🫶", "👌", "🤌"],
            ["👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌"]
        ]),
        ("ANIMALS & NATURE", [
            ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼"],
            ["🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔"],
            ["🐧", "🐦", "🦅", "🦆", "🦢", "🧉", "🦉", "🦜"],
            ["🐝", "🪱", "🐛", "🦋", "🐌", "🐞", "🐜", "🪰"],
            ["🌸", "🌹", "🌺", "🌻", "🌼", "🌷", "🌱", "🌲"],
            ["☀️", "🌤️", "⛅", "🌧️", "⛈️", "❄️", "🌈", "🌊"]
        ]),
        ("FOOD & DRINK", [
            ["🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓"],
            ["🍒", "🍑", "🥑", "🍔", "🍟", "🍕", "🌮", "🍣"],
            ["🥪", "🌭", "🍿", "🥚", "🥘", "🥙", "🥗", "🥫"],
            ["🍩", "🍪", "🎂", "🍰", "🧁", "🍫", "🍬", "🍭"],
            ["☕️", "🍵", "🧃", "🥤", "🍺", "🍻", "🍷", "🥂"]
        ]),
        ("ACTIVITY", [
            ["⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🎱", "🏓"],
            ["🏃", "💃", "🕺", "🚴", "🏆", "🎮", "🎲", "🎯"],
            ["⛳", "🏒", "🏑", "🏏", "🥊", "🥋", "🤺", "⛷️"],
            ["🎵", "🎤", "🎧", "🎬", "🎨", "🎭", "🎸", "🎹"]
        ]),
        ("TRAVEL & PLACES", [
            ["🚗", "🚕", "🚌", "🚎", "🏎️", "🚓", "✈️", "🚀"],
            ["🚙", "🚒", "🚑", "🚚", "🏍️", "🚲", "🚂", "🚢"],
            ["🏠", "🏡", "🏢", "🏥", "🏫", "🏖️", "🏝️", "⛰️"],
            ["🗽", "🗼", "🏰", "🌋", "🏕️", "🌅", "🌄", "🌃"]
        ]),
        ("OBJECTS", [
            ["⌚️", "📱", "💻", "⌨️", "🖥️", "🖨️", "🖱️", "💽"],
            ["📷", "📹", "🎥", "📺", "📻", "🎙️", "🎧", "📡"],
            ["💡", "🔦", "🕯️", "📔", "📕", "📖", "📚", "📰"],
            ["✏️", "📝", "📌", "📎", "✂️", "🔒", "🔑", "🛠️"]
        ]),
        ("SYMBOLS", [
            ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍"],
            ["💯", "💢", "💥", "💫", "💦", "💨", "🕳️", "💬"],
            ["✅", "❌", "❗", "❓", "⚠️", "🚫", "🔞", "♻️"],
            ["⬆️", "↗️", "➡️", "↘️", "⬇️", "↙️", "⬅️", "↖️"]
        ]),
        ("FLAGS", [
            ["🇺🇸", "🇨🇦", "🇬🇧", "🇫🇷", "🇩🇪", "🇮🇹", "🇪🇸", "🇵🇹"],
            ["🇮🇷", "🇹🇷", "🇸🇦", "🇮🇳", "🇨🇳", "🇯🇵", "🇰🇷", "🇦🇺"],
            ["🇧🇷", "🇲🇽", "🇦🇷", "🇿🇦", "🇳🇬", "🇰🇪", "🇪🇬", "🇦🇪"]
        ])
    ]

    private let languages: [String] = {
        let all = [
            "Afrikaans", "Albanian", "Amharic", "Arabic", "Armenian", "Azerbaijani",
            "Basque", "Bengali", "Bulgarian",
            "Catalan", "Chinese Simplified", "Chinese Traditional", "Croatian", "Czech",
            "Danish", "Dutch",
            "English", "Estonian",
            "Filipino", "Finnish", "French",
            "Georgian", "German", "Greek", "Gujarati",
            "Hausa", "Hebrew", "Hindi", "Hungarian",
            "Icelandic", "Igbo", "Indonesian", "Irish", "Italian",
            "Japanese",
            "Kannada", "Kazakh", "Korean",
            "Latvian", "Lithuanian",
            "Macedonian", "Malay", "Malayalam", "Marathi", "Mongolian",
            "Nepali", "Norwegian",
            "Pashto", "Persian", "Polish", "Portuguese", "Punjabi",
            "Romanian", "Russian",
            "Serbian", "Sinhala", "Slovak", "Slovenian", "Somali", "Spanish", "Swahili", "Swedish",
            "Tagalog", "Tamil", "Telugu", "Thai", "Turkish",
            "Ukrainian", "Urdu",
            "Vietnamese",
            "Welsh",
            "Yoruba",
            "Zulu"
        ]
        return ["Auto"] + all
    }()

    private let languageFlags: [String: String] = [
        "Auto": "🌐",
        "Afrikaans": "🇿🇦", "Albanian": "🇦🇱", "Amharic": "🇪🇹", "Arabic": "🇸🇦",
        "Armenian": "🇦🇲", "Azerbaijani": "🇦🇿",
        "Basque": "🇪🇸", "Bengali": "🇧🇩", "Bulgarian": "🇧🇬",
        "Catalan": "🇪🇸", "Chinese Simplified": "🇨🇳", "Chinese Traditional": "🇹🇼",
        "Croatian": "🇭🇷", "Czech": "🇨🇿",
        "Danish": "🇩🇰", "Dutch": "🇳🇱",
        "English": "🇺🇸", "Estonian": "🇪🇪",
        "Filipino": "🇵🇭", "Finnish": "🇫🇮", "French": "🇫🇷",
        "Georgian": "🇬🇪", "German": "🇩🇪", "Greek": "🇬🇷", "Gujarati": "🇮🇳",
        "Hausa": "🇳🇬", "Hebrew": "🇮🇱", "Hindi": "🇮🇳", "Hungarian": "🇭🇺",
        "Icelandic": "🇮🇸", "Igbo": "🇳🇬", "Indonesian": "🇮🇩", "Irish": "🇮🇪", "Italian": "🇮🇹",
        "Japanese": "🇯🇵",
        "Kannada": "🇮🇳", "Kazakh": "🇰🇿", "Korean": "🇰🇷",
        "Latvian": "🇱🇻", "Lithuanian": "🇱🇹",
        "Macedonian": "🇲🇰", "Malay": "🇲🇾", "Malayalam": "🇮🇳", "Marathi": "🇮🇳", "Mongolian": "🇲🇳",
        "Nepali": "🇳🇵", "Norwegian": "🇳🇴",
        "Pashto": "🇦🇫", "Persian": "🇮🇷", "Polish": "🇵🇱", "Portuguese": "🇵🇹", "Punjabi": "🇮🇳",
        "Romanian": "🇷🇴", "Russian": "🇷🇺",
        "Serbian": "🇷🇸", "Sinhala": "🇱🇰", "Slovak": "🇸🇰", "Slovenian": "🇸🇮",
        "Somali": "🇸🇴", "Spanish": "🇪🇸", "Swahili": "🇰🇪", "Swedish": "🇸🇪",
        "Tagalog": "🇵🇭", "Tamil": "🇮🇳", "Telugu": "🇮🇳", "Thai": "🇹🇭", "Turkish": "🇹🇷",
        "Ukrainian": "🇺🇦", "Urdu": "🇵🇰",
        "Vietnamese": "🇻🇳",
        "Welsh": "🏴󠁧󠁢󠁷󠁬󠁳󠁿",
        "Yoruba": "🇳🇬",
        "Zulu": "🇿🇦",
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshRecentEmojiCategory()
        keyboardHeightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardNormalHeight)
        keyboardHeightConstraint?.priority = .defaultHigh
        keyboardHeightConstraint?.isActive = true
        setupKeyboard()
        warmUpServer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if keyboardMode == .customToneInput, customToneCursorTimer == nil {
            startCustomToneCursorBlinking()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelTransientWork()
    }

    deinit {
        warmupTask?.cancel()
        textOperationTask?.cancel()
        statusTask?.cancel()
        bannerDismissTask?.cancel()
        speakTask?.cancel()
        speechTranslationTask?.cancel()
        deleteTimer?.invalidate()
        customToneCursorTimer?.invalidate()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        guard keyboardMode == .letters, !capsLocked else { return }
        lastShiftTapTime = nil
        scheduleShiftReconciliation()
    }

    private func warmUpServer() {
        guard let url = URL(string: "https://refinekeyboard-api.onrender.com/health") else { return }
        warmupTask?.cancel()
        let task = URLSession.shared.dataTask(with: url) { [weak self] _, _, _ in
            self?.warmupTask = nil
        }
        warmupTask = task
        task.resume()
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
        keyboardRootView = root

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6)
        ])

        // ── Three-box action row: [AI ✦] [EN · Refine ⌃⌄] [FA · Translate] ──
        let actionRow = UIStackView()
        actionRow.axis = .horizontal
        actionRow.spacing = 6
        actionRow.distribution = .fill
        actionRow.heightAnchor.constraint(equalToConstant: actionRowHeight).isActive = true

        // AI box
        let aiBox = UIView()
        aiBox.backgroundColor = actionPillBackground
        aiBox.layer.cornerRadius = 12
        aiBox.layer.masksToBounds = true
        aiBox.layer.borderWidth = 0.5
        aiBox.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
        aiBox.widthAnchor.constraint(equalToConstant: isIPad ? 80 : 64).isActive = true
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
        aiButton = aiBtn

        let (box1, langBtn1, toneBtn1) = makeBox(
            langIcon: "globe",
            langTitle: languageDisplayTitle(),
            actionIcon: toneIconName(for: currentTone),
            actionTitle: toneName(for: currentTone),
            showsChevron: true,
            langBtnWidth: isIPad ? 88 : 68
        )
        languageButton = langBtn1
        langBtn1.addTarget(self, action: #selector(showRewriteLanguagePicker), for: .touchUpInside)
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
            showsChevron: false,
            langBtnWidth: isIPad ? 88 : 68
        )
        translateLangButton = trLangBtn2
        trLangBtn2.addTarget(self, action: #selector(showTranslateLanguagePicker), for: .touchUpInside)
        translateButton = trBtn2
        trBtn2.addAction(UIAction { [weak self] _ in
            self?.translateSelectedText()
        }, for: .touchUpInside)

        actionRow.addArrangedSubview(aiBox)
        actionRow.addArrangedSubview(box1)
        actionRow.addArrangedSubview(box2)
        // On iPad the screen is much wider — share remaining space equally between the two boxes.
        // On iPhone fix box1 so box2 fills the rest (original behaviour).
        if isIPad {
            box1.widthAnchor.constraint(equalTo: box2.widthAnchor).isActive = true
        } else {
            box1.widthAnchor.constraint(equalToConstant: 164).isActive = true
        }
        root.addArrangedSubview(actionRow)

        keyboardStack.axis = .vertical
        keyboardStack.spacing = isIPad ? 6 : 10
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
        emojiCollectionView = nil
        emojiCategoryButtons.removeAll()
        currentAIReviewView = nil
        customToneDisplayField = nil
        customToneNameField = nil
        customToneCursorTimer?.invalidate()
        customToneCursorTimer = nil
        keyboardHeightConstraint?.constant = keyboardMode == .aiReview ? keyboardAIHeight
                                           : keyboardMode == .customToneInput ? keyboardToneHeight : keyboardNormalHeight

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
        if !capsLocked { syncShiftWithDocumentContext() }
        keyboardStack.addArrangedSubview(makeLetterFastRow("qwertyuiop"))
        keyboardStack.addArrangedSubview(makeLetterFastRow("asdfghjkl", alignsNineKeyRow: true))
        keyboardStack.addArrangedSubview(makeThirdLetterRow())
        keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "123"))
    }

    private func makeLetterFastRow(
        _ letters: String,
        sideInset: CGFloat = 0,
        alignsNineKeyRow: Bool = false
    ) -> FastKeyRow {
        let row = FastKeyRow(
            sideInset: sideInset,
            alignsNineKeyRow: alignsNineKeyRow,
            background: letterKeyBackground
        )
        row.heightAnchor.constraint(equalToConstant: keyRowHeight).isActive = true
        row.keyPreview = keyPreview
        row.previewContainer = view
        for char in letters {
            let base = String(char)
            let display = (isShifted || capsLocked) ? base.uppercased() : base.lowercased()
            row.addKey(base: base, display: display, font: .systemFont(ofSize: letterFontSize, weight: .regular)) { [weak self] in
                guard let self else { return }
                self.insertUserText((self.isShifted || self.capsLocked) ? base.uppercased() : base.lowercased())
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
        keyboardStack.addArrangedSubview(makeEmojiCollectionView())
        keyboardStack.addArrangedSubview(makeEmojiTabsRow())
    }

    private func makeCommandRow(modeTitle: String) -> UIStackView {
        let commandRow = UIStackView()
        commandRow.axis = .horizontal
        commandRow.spacing = 6
        commandRow.distribution = .fill

        if needsInputModeSwitchKey {
            let globe = makeSystemButton(title: "")
            let sym = UIImage.SymbolConfiguration(pointSize: 16, weight: .light)
            globe.setImage(UIImage(systemName: "globe", withConfiguration: sym), for: .normal)
            globe.widthAnchor.constraint(equalToConstant: sideButtonWidth).isActive = true
            globe.addTarget(
                self,
                action: #selector(handleInputModeList(from:with:)),
                for: .allTouchEvents
            )
            commandRow.addArrangedSubview(globe)
        }

        let mode = makeSystemButton(title: modeTitle)
        mode.widthAnchor.constraint(equalToConstant: sideButtonWidth).isActive = true
        addTapAction(to: mode) { [weak self] in
            guard let self else { return }
            if self.keyboardMode == .customToneInput {
                self.customToneKeyboardPage = modeTitle == "ABC" ? .letters : .numbers
            } else {
                self.keyboardMode = modeTitle == "ABC" ? .letters : .numbers
            }
            self.renderKeyboard()
        }
        commandRow.addArrangedSubview(mode)

        let emoji = makeSystemButton(title: nil, imageName: "face.smiling", imagePointSize: 20)
        emoji.widthAnchor.constraint(equalToConstant: isIPad ? 62 : 47).isActive = true
        addTapAction(to: emoji) { [weak self] in
            guard let self else { return }
            if self.keyboardMode == .customToneInput {
                self.customToneKeyboardPage = .emoji
            } else {
                self.keyboardMode = .emoji
            }
            self.renderKeyboard()
        }
        commandRow.addArrangedSubview(emoji)

        let space = makeKeyButton(title: "", showsPreview: false)
        addCharacterAction(to: space) { [weak self] in
            self?.insertCharacter(" ")
        }
        commandRow.addArrangedSubview(space)

        let enter = makeSystemButton(title: nil, imageName: "return", imagePointSize: 20)
        enter.widthAnchor.constraint(equalToConstant: 100).isActive = true
        addCharacterAction(to: enter) { [weak self] in
            self?.insertCharacter("\n")
        }
        commandRow.addArrangedSubview(enter)

        return commandRow
    }

    private func triggerAIReview() {
        if keyboardMode == .aiReview {
            stopSpeaking()
            keyboardMode = .letters
            renderKeyboard()
            return
        }

        guard hasFullAccess else { showStatus("Enable Full Access"); return }
        guard KeyboardSettings.canUseAI else { showStatus("Subscribe in app"); return }
        guard beginTextOperation() else { return }

        let selected = textDocumentProxy.selectedText ?? ""
        if !selected.isEmpty {
            presentAIReview(originalText: selected, rawText: "", usingSelection: true)
            finishTextOperation()
        } else {
            showStatus("Reading text...")
            captureFullDraft { [weak self] snapshot in
                guard let self else { return }
                self.presentAIReview(
                    originalText: snapshot.trimmed,
                    rawText: snapshot.raw,
                    usingSelection: false
                )
                self.finishTextOperation()
            }
        }
    }

    private func presentAIReview(originalText: String, rawText: String, usingSelection: Bool) {
        guard !originalText.isEmpty else { showStatus("Type or select text"); return }

        aiUsingSelection = usingSelection
        aiOriginalText = originalText
        aiContextBefore = usingSelection ? "" : rawText
        aiContextAfter = ""

        stopSpeaking()
        aiRefinedText = ""
        aiTranslatedText = nil
        aiCustomInstruction = ""
        keyboardMode = .aiReview
        renderKeyboard()
        currentAIReviewView?.showOriginalText(aiOriginalText)
    }

    private func runAIRefine(tone: RewriteMode, customInstruction: String = "") {
        guard KeyboardSettings.canUseAI else {
            currentAIReviewView?.showError("Subscribe in app to continue")
            return
        }
        guard beginTextOperation() else { return }
        KeyboardSettings.consumeFreeUse()
        let remaining = KeyboardSettings.freeUsesRemaining
        if !KeyboardSettings.isSubscriptionActive && remaining == 0 {
            showStatus("Last free rewrite used — Subscribe in app")
        } else if !KeyboardSettings.isSubscriptionActive {
            showStatus("\(remaining) free rewrite\(remaining == 1 ? "" : "s") left")
        }

        // Keep the target captured when the AI panel was opened. The document-context
        // properties are intentionally limited by many host apps and may contain only
        // the sentence or paragraph nearest the cursor, not the complete text field.
        currentAIReviewView?.showOriginalText(aiOriginalText)

        aiTranslatedText = nil
        currentAIReviewView?.setLoading(true)
        let requestGeneration = prepareTextOperationTask()
        textOperationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let refined = try await client.rewrite(
                    text: aiOriginalText, mode: tone,
                    language: outputLanguage, customInstruction: customInstruction)
                await MainActor.run {
                    guard self.isCurrentTextOperationTask(requestGeneration), !Task.isCancelled else { return }
                    self.aiRefinedText = refined
                    self.currentAIReviewView?.setContent(original: self.aiOriginalText, refined: refined)
                    self.completeTextOperationTask(requestGeneration)
                }
            } catch {
                await MainActor.run {
                    guard self.isCurrentTextOperationTask(requestGeneration) else { return }
                    if !Task.isCancelled {
                        self.currentAIReviewView?.showError(self.message(for: error))
                    }
                    self.completeTextOperationTask(requestGeneration)
                }
            }
        }
    }

    private func beginTextOperation() -> Bool {
        guard !isTextOperationInProgress else { return false }
        isTextOperationInProgress = true
        updateTextOperationControls()
        return true
    }

    private func finishTextOperation() {
        isTextOperationInProgress = false
        updateTextOperationControls()
    }

    private func prepareTextOperationTask() -> Int {
        textOperationTask?.cancel()
        textOperationGeneration &+= 1
        return textOperationGeneration
    }

    private func isCurrentTextOperationTask(_ generation: Int) -> Bool {
        generation == textOperationGeneration
    }

    private func completeTextOperationTask(_ generation: Int) {
        guard isCurrentTextOperationTask(generation) else { return }
        textOperationTask = nil
        finishTextOperation()
    }

    private func updateTextOperationControls() {
        let enabled = !isTextOperationInProgress
        [aiButton, toneButton, translateButton].forEach {
            $0?.isEnabled = enabled
            $0?.alpha = enabled ? 1 : 0.45
        }
    }

    private func cancelTransientWork() {
        warmupTask?.cancel()
        warmupTask = nil

        fullTextCaptureGeneration &+= 1
        isCapturingFullText = false

        textOperationGeneration &+= 1
        textOperationTask?.cancel()
        textOperationTask = nil

        statusTask?.cancel()
        statusTask = nil
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        shiftSyncGeneration &+= 1

        deleteTimer?.invalidate()
        deleteTimer = nil
        customToneCursorTimer?.invalidate()
        customToneCursorTimer = nil

        stopSpeaking()
        currentAIReviewView?.setTargetLoading(false)
        currentAIReviewView?.setPlayingEN(false)
        currentAIReviewView?.setPlayingTarget(false)
        if keyboardMode == .aiReview, aiRefinedText.isEmpty, !aiOriginalText.isEmpty {
            currentAIReviewView?.showOriginalText(aiOriginalText)
        }

        keyPreview.hide()
        translationBanner.hide(animated: false)
        finishTextOperation()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopSpeaking() {
        speechTranslationTask?.cancel()
        speechTranslationTask = nil
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
                // For the target-language button pass the language so the backend
                // can pick a voice suited to that script (e.g. onyx for Persian).
                let lang = target == .target ? KeyboardSettings.translateLanguage : "English"
                req.httpBody = try JSONEncoder().encode([
                    "text": text,
                    "voice": "nova",   // backend overrides this based on language
                    "language": lang
                ])
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
            self.customToneBuffer = ""
            self.customToneNameBuffer = ""
            self.customToneCursorOffset = 0
            self.customToneNameCursorOffset = 0
            self.customToneNaming = true
            self.customToneKeyboardPage = .letters
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
                // insertText replaces only the active selection.
                self.textDocumentProxy.insertText(textToInsert)
            } else {
                // No selection: replace the complete snapshot captured when the panel opened.
                self.replaceCurrentDraft(
                    contextBeforeInput: self.aiContextBefore,
                    contextAfterInput: self.aiContextAfter,
                    refined: textToInsert
                )
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
                self.speechTranslationTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        let translated = try await self.client.rewrite(
                            text: textToSpeak, mode: .translate, language: targetLang,
                            customInstruction: "")
                        await MainActor.run {
                            guard !Task.isCancelled else { return }
                            self.speechTranslationTask = nil
                            self.aiTranslatedText = translated
                            self.currentAIReviewView?.setTargetLoading(false)
                            speak(translated)
                        }
                    } catch {
                        await MainActor.run {
                            self.speechTranslationTask = nil
                            self.currentAIReviewView?.setTargetLoading(false)
                            if !Task.isCancelled {
                                self.currentAIReviewView?.showError("Translation failed — try again")
                            }
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
        updateCustomToneShift()

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
            self?.customToneCursorOffset = 0
            self?.customToneNameCursorOffset = 0
            self?.keyboardMode = .aiReview
            self?.renderKeyboard()
        }, for: .touchUpInside)

        // ── Row 2: tone description ──────────────────────────────────
        let toneTag = makeFieldTag("TONE", active: !customToneNaming)

        let descPill = CustomToneTextFieldView()
        descPill.backgroundColor = pillBg
        descPill.layer.cornerRadius = 9
        descPill.layer.borderWidth = 1.5
        descPill.layer.borderColor = customToneNaming ? UIColor.clear.cgColor : UIColor.systemBlue.cgColor

        customToneDisplayField = descPill

        // ── Row 1: title ──────────────────────────────────────────────
        let nameTag = makeFieldTag("TITLE", active: customToneNaming)

        let namePill = CustomToneTextFieldView()
        namePill.backgroundColor = pillBg
        namePill.layer.cornerRadius = 9
        namePill.layer.borderWidth = 1.5
        namePill.layer.borderColor = customToneNaming ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor

        customToneNameField = namePill

        // Activate the tapped field and position its caret nearest the tap.
        descPill.onCursorMove = { [weak self, weak descPill, weak namePill,
                                   weak toneTag, weak nameTag] offset in
            guard let self else { return }
            self.customToneNaming = false
            self.customToneCursorOffset = min(max(0, offset), self.customToneBuffer.count)
            self.updateCustomToneShift()
            self.refreshCustomToneFieldLabels(caretVisible: true)
            descPill?.layer.borderColor = UIColor.systemBlue.cgColor
            namePill?.layer.borderColor = UIColor.clear.cgColor
            toneTag?.textColor = .systemBlue
            nameTag?.textColor = .tertiaryLabel
        }

        namePill.onCursorMove = { [weak self, weak descPill, weak namePill,
                                   weak toneTag, weak nameTag] offset in
            guard let self else { return }
            self.customToneNaming = true
            self.customToneNameCursorOffset = min(max(0, offset), self.customToneNameBuffer.count)
            self.updateCustomToneShift()
            self.refreshCustomToneFieldLabels(caretVisible: true)
            namePill?.layer.borderColor = UIColor.systemBlue.cgColor
            descPill?.layer.borderColor = UIColor.clear.cgColor
            nameTag?.textColor = .systemBlue
            toneTag?.textColor = .tertiaryLabel
        }

        // Applies the tone now without adding it to the saved tone list.
        let applyBtn = UIButton(type: .system)
        styleCustomToneActionButton(
            applyBtn,
            title: "Use Once",
            imageName: "play.fill",
            color: .systemBlue
        )
        applyBtn.addAction(UIAction { [weak self] _ in
            guard let self, !self.customToneBuffer.isEmpty else { return }
            self.applyCustomTone(save: false)
        }, for: .touchUpInside)

        // Stores the tone in a reusable slot and also applies it now.
        let saveBtn = UIButton(type: .system)
        styleCustomToneActionButton(
            saveBtn,
            title: "Save",
            imageName: "bookmark.fill",
            color: .systemOrange
        )
        saveBtn.addAction(UIAction { [weak self, weak descPill] _ in
            guard let self, !self.customToneBuffer.isEmpty else { return }
            guard KeyboardSettings.savedTones.count < 4 else {
                descPill?.showTemporaryMessage("Max 4 saved — tap − on a tone to delete")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self, weak descPill] in
                    guard let self else { return }
                    descPill?.clearTemporaryMessage()
                    self.refreshCustomToneFieldLabels(caretVisible: true)
                }
                return
            }
            self.applyCustomTone(save: true)
        }, for: .touchUpInside)

        // ── Layout: pill tap targets ──────────────────────────────────
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

            // Row 1: TITLE + title field
            nameTag.leadingAnchor.constraint(equalTo: cancelBtn.trailingAnchor, constant: 4),
            nameTag.centerYAnchor.constraint(equalTo: cancelBtn.centerYAnchor),
            nameTag.widthAnchor.constraint(equalToConstant: 38),
            namePill.leadingAnchor.constraint(equalTo: nameTag.trailingAnchor, constant: 4),
            namePill.trailingAnchor.constraint(equalTo: applyBtn.leadingAnchor, constant: -6),
            namePill.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            namePill.heightAnchor.constraint(equalToConstant: 32),

            // Right-side action column: the primary one-time action sits above Save.
            applyBtn.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10),
            applyBtn.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            applyBtn.widthAnchor.constraint(equalToConstant: isIPad ? 94 : 78),
            applyBtn.heightAnchor.constraint(equalToConstant: 32),
            saveBtn.trailingAnchor.constraint(equalTo: applyBtn.trailingAnchor),
            saveBtn.topAnchor.constraint(equalTo: applyBtn.bottomAnchor, constant: 8),
            saveBtn.widthAnchor.constraint(equalTo: applyBtn.widthAnchor),
            saveBtn.heightAnchor.constraint(equalToConstant: 28),

            // Row 2: TONE description
            toneTag.leadingAnchor.constraint(equalTo: nameTag.leadingAnchor),
            toneTag.centerYAnchor.constraint(equalTo: descPill.centerYAnchor),
            toneTag.widthAnchor.constraint(equalToConstant: 38),
            descPill.leadingAnchor.constraint(equalTo: toneTag.trailingAnchor, constant: 4),
            descPill.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -6),
            descPill.topAnchor.constraint(equalTo: namePill.bottomAnchor, constant: 8),
            descPill.heightAnchor.constraint(equalToConstant: 28),

            // Separator
            sep.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        keyboardStack.addArrangedSubview(headerView)
        switch customToneKeyboardPage {
        case .letters:
            keyboardStack.addArrangedSubview(makeLetterFastRow("qwertyuiop"))
            keyboardStack.addArrangedSubview(makeLetterFastRow("asdfghjkl", sideInset: 20))
            keyboardStack.addArrangedSubview(makeThirdLetterRow())
            keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "123"))
        case .numbers:
            keyboardStack.addArrangedSubview(makeTextRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]))
            keyboardStack.addArrangedSubview(makeTextRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]))
            keyboardStack.addArrangedSubview(makeSymbolRow(cornerTitle: "#+=") { [weak self] in
                self?.customToneKeyboardPage = .symbols
                self?.renderKeyboard()
            })
            keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "ABC"))
        case .symbols:
            keyboardStack.addArrangedSubview(makeTextRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]))
            keyboardStack.addArrangedSubview(makeTextRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]))
            keyboardStack.addArrangedSubview(makeSymbolRow(cornerTitle: "123") { [weak self] in
                self?.customToneKeyboardPage = .numbers
                self?.renderKeyboard()
            })
            keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "ABC"))
        case .emoji:
            keyboardStack.addArrangedSubview(makeEmojiCollectionView())
            keyboardStack.addArrangedSubview(makeEmojiTabsRow())
        }

        startCustomToneCursorBlinking()
    }

    private func startCustomToneCursorBlinking() {
        customToneCursorTimer?.invalidate()
        var cursorOn = true
        refreshCustomToneFieldLabels(caretVisible: true)
        customToneCursorTimer = Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { [weak self] _ in
            guard let self else { return }
            cursorOn.toggle()
            self.refreshCustomToneFieldLabels(caretVisible: cursorOn)
        }
    }

    private func makeFieldTag(_ text: String, active: Bool) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 10, weight: .bold)
        l.textColor = active ? .systemBlue : .tertiaryLabel
        return l
    }

    private func styleCustomToneActionButton(
        _ button: UIButton,
        title: String,
        imageName: String,
        color: UIColor
    ) {
        button.setImage(UIImage(systemName: imageName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)), for: .normal)
        button.setTitle(" " + title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 10, weight: .semibold)
        button.tintColor = color
        button.setTitleColor(color, for: .normal)
        button.backgroundColor = color.withAlphaComponent(0.12)
        button.layer.cornerRadius = 8
    }

    private func refreshCustomToneFieldLabels(caretVisible: Bool = false) {
        customToneNameField?.update(
            value: customToneNameBuffer,
            placeholder: "Give this tone a title…",
            cursorOffset: customToneNameCursorOffset,
            active: customToneNaming,
            caretVisible: caretVisible
        )
        customToneDisplayField?.update(
            value: customToneBuffer,
            placeholder: "Describe the tone or style…",
            cursorOffset: customToneCursorOffset,
            active: !customToneNaming,
            caretVisible: caretVisible
        )
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
        customToneCursorOffset = 0
        customToneNameCursorOffset = 0
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
        row.heightAnchor.constraint(equalToConstant: keyRowHeight).isActive = true
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
        if !isIPad { row.spacing = 14 }

        let corner = makeSystemButton(title: cornerTitle)
        corner.widthAnchor.constraint(equalToConstant: letterSideButtonWidth).isActive = true
        addTapAction(to: corner, action: cornerAction)
        row.addArrangedSubview(corner)

        let keysRow = makeTextRow([".", ",", "?", "!", "'"])
        row.addArrangedSubview(keysRow)

        let delete = makeSystemButton(title: nil, imageName: "delete.left")
        delete.widthAnchor.constraint(equalToConstant: letterSideButtonWidth).isActive = true
        addDeleteAction(to: delete)
        row.addArrangedSubview(delete)

        return row
    }

    private func recordRecentEmoji(_ emoji: String) {
        let key = "recentEmojis"
        var recent = KeyboardSettings.sharedDefaults.stringArray(forKey: key) ?? []
        recent.removeAll { $0 == emoji }
        recent.insert(emoji, at: 0)
        KeyboardSettings.sharedDefaults.set(Array(recent.prefix(24)), forKey: key)
        refreshRecentEmojiCategory()
    }

    private func refreshRecentEmojiCategory() {
        guard !emojiCategories.isEmpty else { return }
        let defaults = emojiCategories[0].1.flatMap { $0 }
        let stored = KeyboardSettings.sharedDefaults.stringArray(forKey: "recentEmojis") ?? []
        var items = stored
        for emoji in defaults where !items.contains(emoji) {
            items.append(emoji)
        }
        items = Array(items.prefix(24))

        var rows: [[String]] = []
        for start in stride(from: 0, to: items.count, by: 8) {
            rows.append(Array(items[start..<min(start + 8, items.count)]))
        }
        emojiCategories[0] = (emojiCategories[0].0, rows)
    }

    private func makeEmojiCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 2
        layout.sectionInset = UIEdgeInsets(top: 0, left: 4, bottom: 10, right: 4)
        layout.headerReferenceSize = CGSize(width: 1, height: 22)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.heightAnchor.constraint(equalToConstant: 154).isActive = true
        collectionView.register(
            EmojiCollectionCell.self,
            forCellWithReuseIdentifier: EmojiCollectionCell.reuseIdentifier
        )
        collectionView.register(
            EmojiSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: EmojiSectionHeader.reuseIdentifier
        )
        emojiCollectionView = collectionView
        return collectionView
    }

    private func emoji(at indexPath: IndexPath) -> String? {
        guard emojiCategories.indices.contains(indexPath.section) else { return nil }
        var remainingIndex = indexPath.item
        for row in emojiCategories[indexPath.section].1 {
            if row.indices.contains(remainingIndex) {
                return row[remainingIndex]
            }
            remainingIndex -= row.count
        }
        return nil
    }

    private func makeThirdLetterRow() -> UIStackView {
        let row = makeRow()
        row.distribution = .fill
        if !isIPad { row.spacing = 14 }

        let shift = makeSystemButton(title: nil, imageName: "shift")
        shift.widthAnchor.constraint(equalToConstant: letterSideButtonWidth).isActive = true
        shiftButton = shift
        addTapAction(to: shift) { [weak self] in
            guard let self else { return }
            self.shiftSyncGeneration += 1
            let now = Date()
            if self.capsLocked {
                self.capsLocked = false
                self.isShifted = false
                self.lastShiftTapTime = nil
            } else if self.isShifted,
                      let last = self.lastShiftTapTime,
                      now.timeIntervalSince(last) < 0.35 {
                self.capsLocked = true
                self.isShifted = true
                self.lastShiftTapTime = nil
            } else {
                self.isShifted.toggle()
                self.lastShiftTapTime = self.isShifted ? now : nil
            }
            self.refreshLetterCasing()
            self.updateShiftAppearance()
        }
        row.addArrangedSubview(shift)

        row.addArrangedSubview(makeLetterFastRow("zxcvbnm"))

        let delete = makeSystemButton(title: nil, imageName: "delete.left")
        delete.widthAnchor.constraint(equalToConstant: letterSideButtonWidth).isActive = true
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
            guard let self else { return }
            if self.keyboardMode == .customToneInput {
                self.customToneKeyboardPage = .letters
            } else {
                self.keyboardMode = .letters
            }
            self.renderKeyboard()
        }
        row.addArrangedSubview(abc)

        ["clock", "face.smiling", "leaf", "fork.knife", "soccerball", "car", "lightbulb", "number", "flag"].enumerated().forEach { index, iconName in
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: iconName), for: .normal)
            button.tintColor = index == 0 ? .label : .secondaryLabel
            button.layer.cornerRadius = 15
            button.backgroundColor = index == 0 ? specialKeyBackground : .clear
            addTapAction(to: button) { [weak self] in
                self?.scrollToEmojiCategory(index)
            }
            emojiCategoryButtons.append(button)
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
        guard let collectionView = emojiCollectionView,
              index < emojiCategories.count,
              !emojiCategories[index].1.isEmpty else { return }
        selectEmojiCategory(index)
        collectionView.scrollToItem(
            at: IndexPath(item: 0, section: index),
            at: .top,
            animated: true
        )
    }

    private func selectEmojiCategory(_ selectedIndex: Int) {
        for (index, button) in emojiCategoryButtons.enumerated() {
            let selected = index == selectedIndex
            button.tintColor = selected ? .label : .secondaryLabel
            button.backgroundColor = selected ? specialKeyBackground : .clear
        }
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
        langBtn.titleLabel?.lineBreakMode = .byTruncatingTail
        langBtn.contentHorizontalAlignment = .center
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
        actionBtn.titleLabel?.lineBreakMode = .byTruncatingTail
        actionBtn.contentHorizontalAlignment = .center
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
            actionBtn.trailingAnchor.constraint(equalTo: box.trailingAnchor,
                                                constant: showsChevron ? -20 : 0),
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
        button.layer.cornerRadius = 6
        button.layer.masksToBounds = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0.5
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        if showsPreview {
            addKeyPreview(to: button)
        } else {
            addPressFeedback(to: button)
        }
        return button
    }

    private func makeSystemButton(
        title: String?,
        imageName: String? = nil,
        imagePointSize: CGFloat = 15
    ) -> UIButton {
        let button = UIButton(type: .custom)
        if let title {
            button.setTitle(title, for: .normal)
            button.setTitleColor(.label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.7
        }
        if let imageName {
            let symCfg = UIImage.SymbolConfiguration(pointSize: imagePointSize, weight: .regular)
            button.setImage(UIImage(systemName: imageName, withConfiguration: symCfg), for: .normal)
            button.tintColor = .label
        }
        button.layer.backgroundColor = specialKeyBackground.cgColor
        button.layer.cornerRadius = 6
        button.layer.masksToBounds = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0.5
        button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        addPressFeedback(to: button)
        return button
    }

    private func addTapAction(to button: UIButton, action: @escaping () -> Void) {
        button.addAction(UIAction { _ in
            UIDevice.current.playInputClick()
            action()
        }, for: .touchUpInside)
    }

    private func addCharacterAction(to button: UIButton, action: @escaping () -> Void) {
        // Match the system keyboard: highlight/preview on touch-down, commit on release.
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
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
        let initialTimer = Timer(timeInterval: 0.45, repeats: false) { [weak self] _ in
            guard let self else { return }
            let repeatTimer = Timer(timeInterval: 0.085, repeats: true) { [weak self] _ in
                self?.deleteCharacter()
            }
            self.deleteTimer = repeatTimer
            RunLoop.main.add(repeatTimer, forMode: .common)
        }
        deleteTimer = initialTimer
        // Common mode keeps repeat active while UIKit is tracking the held touch.
        RunLoop.main.add(initialTimer, forMode: .common)
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
        UIDevice.current.playInputClick()
        if keyboardMode == .customToneInput {
            if customToneNaming {
                (customToneNameBuffer, customToneNameCursorOffset) = Self.inserting(
                    text, into: customToneNameBuffer, at: customToneNameCursorOffset
                )
            } else {
                (customToneBuffer, customToneCursorOffset) = Self.inserting(
                    text, into: customToneBuffer, at: customToneCursorOffset
                )
            }
            updateCustomToneShift()
            refreshCustomToneFieldLabels(caretVisible: true)
            return
        }

        let contextBeforeInsertion = textDocumentProxy.documentContextBeforeInput
        textDocumentProxy.insertText(text)

        if !capsLocked {
            lastShiftTapTime = nil
            if let contextBeforeInsertion {
                applyAutomaticShift(for: contextBeforeInsertion + text)
            }
            scheduleShiftReconciliation()
        }
    }

    private func deleteUserText() {
        UIDevice.current.playInputClick()
        if keyboardMode == .customToneInput {
            if customToneNaming {
                (customToneNameBuffer, customToneNameCursorOffset) = Self.deletingBackward(
                    in: customToneNameBuffer, at: customToneNameCursorOffset
                )
            } else {
                (customToneBuffer, customToneCursorOffset) = Self.deletingBackward(
                    in: customToneBuffer, at: customToneCursorOffset
                )
            }
            updateCustomToneShift()
            refreshCustomToneFieldLabels(caretVisible: true)
            return
        }

        let contextBeforeDeletion = textDocumentProxy.documentContextBeforeInput
        textDocumentProxy.deleteBackward()

        guard !capsLocked else { return }
        lastShiftTapTime = nil
        if let contextBeforeDeletion {
            applyAutomaticShift(for: String(contextBeforeDeletion.dropLast()))
        }
        scheduleShiftReconciliation()
    }

    private func syncShiftWithDocumentContext() {
        guard !capsLocked,
              let context = textDocumentProxy.documentContextBeforeInput else { return }

        applyAutomaticShift(for: context)
    }

    private func scheduleShiftReconciliation() {
        shiftSyncGeneration += 1
        let generation = shiftSyncGeneration

        // Some host apps update UITextDocumentProxy asynchronously. The expected
        // context above gives immediate feedback; these reads then reconcile with
        // the host once its document state has caught up.
        for delay in [0.04, 0.12] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self,
                      self.shiftSyncGeneration == generation,
                      self.keyboardMode == .letters,
                      !self.capsLocked else { return }
                self.syncShiftWithDocumentContext()
            }
        }
    }

    private func applyAutomaticShift(for context: String) {
        guard !capsLocked else { return }
        let shouldShift = Self.shouldAutoCapitalize(
            after: context,
            style: textDocumentProxy.autocapitalizationType ?? .sentences
        )
        setShifted(shouldShift)
    }

    private static func shouldAutoCapitalize(
        after context: String,
        style: UITextAutocapitalizationType
    ) -> Bool {
        switch style {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            return context.isEmpty || context.last?.isWhitespace == true
        case .sentences:
            break
        @unknown default:
            break
        }

        guard !context.isEmpty else { return true }

        // Beginning of a new line is a sentence start, including indentation.
        if let newline = context.lastIndex(of: "\n"),
           context[context.index(after: newline)...].allSatisfy(\.isWhitespace) {
            return true
        }

        guard context.last?.isWhitespace == true else { return false }

        var significant = context[...]
        while significant.last?.isWhitespace == true {
            significant = significant.dropLast()
        }
        guard !significant.isEmpty else { return true }

        // Quotes and brackets commonly follow sentence punctuation: `Hello!\u{201D} `.
        let sentenceClosers: Set<Character> = ["\"", "'", "\u{2019}", "\u{201D}", ")", "]", "}"]
        while let last = significant.last, sentenceClosers.contains(last) {
            significant = significant.dropLast()
        }
        return significant.last.map { ".!?".contains($0) } ?? true
    }

    private func setShifted(_ shifted: Bool) {
        guard isShifted != shifted else {
            updateShiftAppearance()
            return
        }
        isShifted = shifted
        refreshLetterCasing()
        updateShiftAppearance()
    }

    // Auto-capitalize the keyboard-owned custom tone fields too.
    private func updateCustomToneShift() {
        guard !capsLocked else { return }
        let buffer = customToneNaming ? customToneNameBuffer : customToneBuffer
        let offset = customToneNaming ? customToneNameCursorOffset : customToneCursorOffset
        let safeOffset = min(max(0, offset), buffer.count)
        let cursorIndex = buffer.index(buffer.startIndex, offsetBy: safeOffset)
        setShifted(Self.shouldAutoCapitalize(after: String(buffer[..<cursorIndex]), style: .sentences))
    }

    private static func inserting(_ text: String, into value: String, at offset: Int) -> (String, Int) {
        let safeOffset = min(max(0, offset), value.count)
        let index = value.index(value.startIndex, offsetBy: safeOffset)
        var result = value
        result.insert(contentsOf: text, at: index)
        return (result, safeOffset + text.count)
    }

    private static func deletingBackward(in value: String, at offset: Int) -> (String, Int) {
        let safeOffset = min(max(0, offset), value.count)
        guard safeOffset > 0 else { return (value, 0) }
        let cursorIndex = value.index(value.startIndex, offsetBy: safeOffset)
        let deletionIndex = value.index(before: cursorIndex)
        var result = value
        result.remove(at: deletionIndex)
        return (result, safeOffset - 1)
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
    }

    private func updateTranslateLangButton() {
        let sym = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        translateLangButton?.setImage(UIImage(systemName: "arrow.right.circle.fill", withConfiguration: sym), for: .normal)
        translateLangButton?.setTitle(" \(translateLanguageDisplayTitle())", for: .normal)
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

    @objc private func showRewriteLanguagePicker() {
        LanguagePickerOverlay.show(
            in: view,
            title: "Rewrite Language",
            languages: languages,
            flags: languageFlags,
            current: outputLanguage
        ) { [weak self] selected in
            guard let self else { return }
            self.outputLanguage = selected
            KeyboardSettings.sharedDefaults.set(selected, forKey: KeyboardSettings.languageKey)
            self.updateLanguageButtonTitle()
            self.showStatus(selected == "Auto" ? "Rewrite: Auto" : "Rewrite → \(self.languageCode(for: selected))")
            let code = selected == "Auto" ? "Auto" : self.languageCode(for: selected)
            self.currentAIReviewView?.updateSourceLang(code: code)
        }
    }

    @objc private func showTranslateLanguagePicker() {
        let filtered = languages.filter { $0 != "Auto" }
        LanguagePickerOverlay.show(
            in: view,
            title: "Translate To",
            languages: filtered,
            flags: languageFlags,
            current: KeyboardSettings.translateLanguage
        ) { [weak self] selected in
            guard let self else { return }
            KeyboardSettings.sharedDefaults.set(selected, forKey: KeyboardSettings.translateLanguageKey)
            self.updateTranslateLangButton()
            self.showTranslateStatus("→ \(self.languageCode(for: selected))")
            let code = self.languageCode(for: selected)
            self.currentAIReviewView?.updateTargetLang(code: code)
            self.aiTranslatedText = nil
            self.stopSpeaking()
        }
    }

    private func refineCurrentText(mode: RewriteMode) {
        guard hasFullAccess else {
            showStatus("Enable Full Access")
            return
        }
        guard KeyboardSettings.canUseAI else {
            showStatus("Subscribe in app")
            return
        }
        guard beginTextOperation() else { return }
        KeyboardSettings.consumeFreeUse()
        let remaining = KeyboardSettings.freeUsesRemaining
        if !KeyboardSettings.isSubscriptionActive && remaining == 0 {
            showStatus("Last free rewrite used — Subscribe in app")
        } else if !KeyboardSettings.isSubscriptionActive {
            showStatus("\(remaining) free rewrite\(remaining == 1 ? "" : "s") left")
        }

        let selected = textDocumentProxy.selectedText ?? ""
        if !selected.isEmpty {
            startRefinement(
                text: selected,
                mode: mode,
                usingSelection: true,
                contextBeforeInput: "",
                contextAfterInput: ""
            )
        } else {
            showStatus("Reading text...")
            captureFullDraft { [weak self] snapshot in
                guard let self else { return }
                self.startRefinement(
                    text: snapshot.trimmed,
                    mode: mode,
                    usingSelection: false,
                    contextBeforeInput: snapshot.raw,
                    contextAfterInput: ""
                )
            }
        }
    }

    private func startRefinement(
        text: String,
        mode: RewriteMode,
        usingSelection: Bool,
        contextBeforeInput: String,
        contextAfterInput: String
    ) {
        guard !text.isEmpty else {
            showStatus("Type or select text")
            finishTextOperation()
            return
        }

        showStatus("Refining...")

        let requestGeneration = prepareTextOperationTask()
        textOperationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let refined = try await client.rewrite(text: text, mode: mode, language: outputLanguage)
                await MainActor.run {
                    guard self.isCurrentTextOperationTask(requestGeneration), !Task.isCancelled else { return }
                    if refined == text {
                        self.showStatus("No change")
                    } else if usingSelection {
                        // insertText replaces the active selection on iOS
                        self.textDocumentProxy.insertText(refined)
                        self.showStatus("Inserted")
                    } else {
                        self.replaceCurrentDraft(
                            contextBeforeInput: contextBeforeInput,
                            contextAfterInput: contextAfterInput,
                            refined: refined
                        )
                        self.showStatus("Inserted")
                    }
                    self.completeTextOperationTask(requestGeneration)
                }
            } catch {
                await MainActor.run {
                    guard self.isCurrentTextOperationTask(requestGeneration) else { return }
                    if !Task.isCancelled {
                        self.showStatus(self.message(for: error))
                    }
                    self.completeTextOperationTask(requestGeneration)
                }
            }
        }
    }

    private func translateSelectedText() {
        guard hasFullAccess else {
            showTranslateStatus("Enable Full Access")
            return
        }
        guard KeyboardSettings.canUseAI else {
            showTranslateStatus("Subscribe in app")
            return
        }
        guard beginTextOperation() else { return }
        KeyboardSettings.consumeFreeUse()
        let remaining = KeyboardSettings.freeUsesRemaining
        if !KeyboardSettings.isSubscriptionActive && remaining == 0 {
            showTranslateStatus("Last free use — Subscribe in app")
        } else if !KeyboardSettings.isSubscriptionActive {
            showTranslateStatus("\(remaining) free rewrite\(remaining == 1 ? "" : "s") left")
        }

        let selected = textDocumentProxy.selectedText ?? ""
        if !selected.isEmpty {
            startTranslation(source: selected, targetLanguage: KeyboardSettings.translateLanguage)
        } else {
            showTranslateStatus("Reading text...")
            captureFullDraft { [weak self] snapshot in
                self?.startTranslation(
                    source: snapshot.trimmed,
                    targetLanguage: KeyboardSettings.translateLanguage
                )
            }
        }
    }

    private func startTranslation(source: String, targetLanguage: String) {
        guard !source.isEmpty else {
            showTranslateStatus("Type or select text")
            finishTextOperation()
            return
        }

        translateButton?.setTitle(" Translating...", for: .normal)
        translateButton?.setImage(nil, for: .normal)
        bannerDismissTask?.cancel()
        translationBanner.hide(animated: false)

        let requestGeneration = prepareTextOperationTask()
        textOperationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let translated = try await client.rewrite(text: source, mode: .translate, language: targetLanguage)
                await MainActor.run {
                    guard self.isCurrentTextOperationTask(requestGeneration), !Task.isCancelled else { return }
                    self.lastTranslation = translated
                    self.updateTranslateButton()
                    self.showTranslation(translated, language: targetLanguage)
                    self.completeTextOperationTask(requestGeneration)
                }
            } catch {
                await MainActor.run {
                    guard self.isCurrentTextOperationTask(requestGeneration) else { return }
                    if !Task.isCancelled {
                        self.showTranslateStatus(self.message(for: error))
                    }
                    self.completeTextOperationTask(requestGeneration)
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

    private typealias DraftSnapshot = (raw: String, trimmed: String)

    /// Captures the complete host text field. Host apps such as WhatsApp apply proxy cursor
    /// movements on a later run-loop pass, so every move must settle before context is read.
    private func captureFullDraft(completion: @escaping (DraftSnapshot) -> Void) {
        // Incrementing the generation invalidates every delayed callback belonging to
        // an older capture. Only the newest capture may continue or call completion.
        fullTextCaptureGeneration &+= 1
        let generation = fullTextCaptureGeneration
        isCapturingFullText = true
        let nearbyText = (textDocumentProxy.documentContextBeforeInput ?? "")
            + (textDocumentProxy.documentContextAfterInput ?? "")

        // Large offsets are clamped by some hosts at sentence, newline, or emoji
        // boundaries. Walk backward through each available context window instead.
        moveToDraftStart(remainingChunks: 500, delay: 0.05, generation: generation) { [weak self] in
            self?.collectDraftChunks(
                collected: "",
                nearbyText: nearbyText,
                remainingChunks: 500,
                readRetries: 3,
                delay: 0.05,
                generation: generation,
                completion: completion
            )
        }
    }

    private func moveToDraftStart(
        remainingChunks: Int,
        delay: TimeInterval,
        generation: Int,
        completion: @escaping () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isCurrentCapture(generation) else { return }

            let chunkBeforeCursor = self.textDocumentProxy.documentContextBeforeInput ?? ""
            guard remainingChunks > 0 else {
                completion()
                return
            }

            guard !chunkBeforeCursor.isEmpty else {
                self.probePastDraftBoundary(
                    remainingChunks: remainingChunks,
                    generation: generation,
                    completion: completion
                )
                return
            }

            self.textDocumentProxy.adjustTextPosition(
                byCharacterOffset: -chunkBeforeCursor.count
            )
            self.moveToDraftStart(
                remainingChunks: remainingChunks - 1,
                delay: 0.05,
                generation: generation,
                completion: completion
            )
        }
    }

    /// An empty context can mean either the true start or a privacy/context boundary inserted
    /// by the host. Probe one character backward; a changed after-context proves we crossed a
    /// boundary and should keep scanning.
    private func probePastDraftBoundary(
        remainingChunks: Int,
        generation: Int,
        completion: @escaping () -> Void
    ) {
        let afterBeforeProbe = textDocumentProxy.documentContextAfterInput ?? ""
        textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.isCurrentCapture(generation) else { return }
            let afterProbe = self.textDocumentProxy.documentContextAfterInput ?? ""
            guard afterProbe != afterBeforeProbe else {
                completion()
                return
            }

            self.moveToDraftStart(
                remainingChunks: remainingChunks - 1,
                delay: 0.05,
                generation: generation,
                completion: completion
            )
        }
    }

    private func collectDraftChunks(
        collected: String,
        nearbyText: String,
        remainingChunks: Int,
        readRetries: Int,
        delay: TimeInterval,
        generation: Int,
        completion: @escaping (DraftSnapshot) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isCurrentCapture(generation) else { return }

            let chunk = self.textDocumentProxy.documentContextAfterInput ?? ""
            if !chunk.isEmpty && remainingChunks > 0 {
                let updated = collected + chunk
                self.textDocumentProxy.adjustTextPosition(byCharacterOffset: chunk.count)
                self.collectDraftChunks(
                    collected: updated,
                    nearbyText: nearbyText,
                    remainingChunks: remainingChunks - 1,
                    readRetries: readRetries,
                    delay: 0.05,
                    generation: generation,
                    completion: completion
                )
                return
            }

            // A host may briefly return no context while applying the previous move.
            if collected.isEmpty && !nearbyText.isEmpty && readRetries > 0 {
                self.collectDraftChunks(
                    collected: "",
                    nearbyText: nearbyText,
                    remainingChunks: remainingChunks,
                    readRetries: readRetries - 1,
                    delay: 0.08,
                    generation: generation,
                    completion: completion
                )
                return
            }

            guard remainingChunks > 0 else {
                self.finishDraftCapture(
                    collected: collected,
                    nearbyText: nearbyText,
                    generation: generation,
                    completion: completion
                )
                return
            }

            self.probeForwardDraftBoundary(
                collected: collected,
                nearbyText: nearbyText,
                remainingChunks: remainingChunks,
                generation: generation,
                completion: completion
            )
        }
    }

    private func probeForwardDraftBoundary(
        collected: String,
        nearbyText: String,
        remainingChunks: Int,
        generation: Int,
        completion: @escaping (DraftSnapshot) -> Void
    ) {
        let beforeProbe = textDocumentProxy.documentContextBeforeInput ?? ""
        textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.isCurrentCapture(generation) else { return }
            let afterProbe = self.textDocumentProxy.documentContextBeforeInput ?? ""

            guard afterProbe != beforeProbe, let crossedCharacter = afterProbe.last else {
                self.finishDraftCapture(
                    collected: collected,
                    nearbyText: nearbyText,
                    generation: generation,
                    completion: completion
                )
                return
            }

            self.collectDraftChunks(
                collected: collected + String(crossedCharacter),
                nearbyText: nearbyText,
                remainingChunks: remainingChunks - 1,
                readRetries: 0,
                delay: 0.05,
                generation: generation,
                completion: completion
            )
        }
    }

    private func finishDraftCapture(
        collected: String,
        nearbyText: String,
        generation: Int,
        completion: (DraftSnapshot) -> Void
    ) {
        guard isCurrentCapture(generation) else { return }
        isCapturingFullText = false
        let raw = collected.count >= nearbyText.count ? collected : nearbyText
        // Forward scanning naturally leaves the cursor at the true end.
        completion((raw, raw.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    private func isCurrentCapture(_ generation: Int) -> Bool {
        isCapturingFullText && generation == fullTextCaptureGeneration
    }

    private func replaceCurrentDraft(contextBeforeInput: String, contextAfterInput: String, refined: String) {
        guard !refined.isEmpty else { return }
        if !contextAfterInput.isEmpty {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: contextAfterInput.count)
        }
        let deletionCount = contextBeforeInput.count + contextAfterInput.count
        (0..<deletionCount).forEach { _ in
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(refined)
    }
}


// A lightweight keyboard-owned text field with a real movable caret. The
// placeholder remains a normal, stable label while only the caret view blinks.
private final class CustomToneTextFieldView: UIView {
    var onCursorMove: ((Int) -> Void)?

    private let textLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let caretView = UIView()
    private var contentWidthConstraint: NSLayoutConstraint!
    private var textWidthConstraint: NSLayoutConstraint!
    private var textLeadingConstraint: NSLayoutConstraint!
    private var caretLeadingConstraint: NSLayoutConstraint!
    private var currentValue = ""
    private var lastValue = ""
    private var lastPlaceholder = ""
    private var lastCursorOffset = -1
    private var lastActive = false
    private var hasTemporaryMessage = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true
        scrollView.isUserInteractionEnabled = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        textLabel.font = .systemFont(ofSize: 13)
        textLabel.numberOfLines = 1
        textLabel.lineBreakMode = .byClipping
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textLabel)

        caretView.backgroundColor = .systemBlue
        caretView.layer.cornerRadius = 0.75
        caretView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(caretView)

        contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: 1)
        textWidthConstraint = textLabel.widthAnchor.constraint(equalToConstant: 1)
        textLeadingConstraint = textLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        caretLeadingConstraint = caretView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            contentWidthConstraint,
            textLeadingConstraint,
            textLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textWidthConstraint,
            caretLeadingConstraint,
            caretView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            caretView.widthAnchor.constraint(equalToConstant: 1.5),
            caretView.heightAnchor.constraint(equalToConstant: 17),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(fieldTapped(_:))))
        let caretDrag = UILongPressGestureRecognizer(target: self, action: #selector(fieldLongPressed(_:)))
        caretDrag.minimumPressDuration = 0.25
        caretDrag.allowableMovement = .greatestFiniteMagnitude
        addGestureRecognizer(caretDrag)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        value: String,
        placeholder: String,
        cursorOffset: Int,
        active: Bool,
        caretVisible: Bool
    ) {
        currentValue = value
        let safeOffset = min(max(0, cursorOffset), value.count)
        if hasTemporaryMessage {
            caretView.isHidden = true
            return
        }
        let contentChanged = value != lastValue || placeholder != lastPlaceholder
        let positionChanged = safeOffset != lastCursorOffset
        let activeFieldChanged = active != lastActive

        if contentChanged {
            textLabel.text = value.isEmpty ? placeholder : value
            textLabel.textColor = value.isEmpty ? .placeholderText : .label
            textWidthConstraint.constant = max(1, ceil(textLabel.intrinsicContentSize.width))
        }

        let prefix = String(value.prefix(safeOffset))
        let caretX = value.isEmpty ? 0 : textWidth(of: prefix)
        textLeadingConstraint.constant = value.isEmpty ? 2 : 0
        caretLeadingConstraint.constant = caretX
        contentWidthConstraint.constant = max(
            textLeadingConstraint.constant + textWidthConstraint.constant,
            caretX + 1.5
        )
        caretView.isHidden = !active
        caretView.alpha = active && caretVisible ? 1 : 0

        lastValue = value
        lastPlaceholder = placeholder
        lastCursorOffset = safeOffset
        lastActive = active
        guard contentChanged || positionChanged || activeFieldChanged else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutIfNeeded()
            let caretRect = self.caretView.convert(self.caretView.bounds, to: self.scrollView)
                .insetBy(dx: -5, dy: 0)
            self.scrollView.scrollRectToVisible(caretRect, animated: false)
        }
    }

    func showTemporaryMessage(_ message: String) {
        hasTemporaryMessage = true
        textLabel.text = message
        textLabel.textColor = .systemRed
        textWidthConstraint.constant = max(1, ceil(textLabel.intrinsicContentSize.width))
        contentWidthConstraint.constant = textLeadingConstraint.constant + textWidthConstraint.constant
    }

    func clearTemporaryMessage() {
        hasTemporaryMessage = false
        lastValue = "\u{0}"
    }

    @objc private func fieldTapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        moveCaret(to: gesture.location(in: scrollView))
    }

    @objc private func fieldLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began || gesture.state == .changed else { return }
        moveCaret(to: gesture.location(in: scrollView))
    }

    private func moveCaret(to location: CGPoint) {
        guard !currentValue.isEmpty else {
            onCursorMove?(0)
            return
        }

        let tappedX = max(0, location.x + scrollView.contentOffset.x - textLeadingConstraint.constant)
        var usedWidth: CGFloat = 0
        for (offset, character) in currentValue.enumerated() {
            let characterWidth = textWidth(of: String(character))
            if tappedX < usedWidth + characterWidth / 2 {
                onCursorMove?(offset)
                return
            }
            usedWidth += characterWidth
        }
        onCursorMove?(currentValue.count)
    }

    private func textWidth(of text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: textLabel.font as Any]).width)
    }
}


// Custom key row with native-style tracking: preview on touch-down, slide between keys,
// and commit the final key only when the finger lifts.
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
    private let alignsNineKeyRow: Bool
    private let keyBackground: UIColor
    private let keySpacing: CGFloat = 6
    private var activeKeyIndex: Int?

    init(sideInset: CGFloat = 0, alignsNineKeyRow: Bool = false, background: UIColor) {
        self.sideInset = sideInset
        self.alignsNineKeyRow = alignsNineKeyRow
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
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = false
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.3
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 0.5
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
        // The native nine-key home row uses half of the missing tenth key on each side.
        // Expressing that inset as a width ratio keeps A–L aligned on every iPhone size.
        let resolvedSideInset = alignsNineKeyRow
            ? bounds.width * 0.05 + keySpacing * 0.05
            : sideInset
        let available = bounds.width - resolvedSideInset * 2
        let keyW = (available - keySpacing * (n - 1)) / n
        for i in keys.indices {
            let x = resolvedSideInset + CGFloat(i) * (keyW + keySpacing)
            let f = CGRect(x: x, y: 0, width: keyW, height: bounds.height)
            keys[i].frame = f
            keys[i].label.frame = f
        }
    }

    // Expand into the native-sized inter-row gap so touches between keys remain forgiving.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: 0, dy: -6).contains(point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pt = touches.first?.location(in: self), !keys.isEmpty else { return }
        let index = nearestIndex(to: pt)
        setActiveKey(index)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pt = touches.first?.location(in: self) else { return }
        let trackingBounds = bounds.insetBy(dx: -12, dy: -18)
        guard trackingBounds.contains(pt) else {
            setActiveKey(nil)
            return
        }

        let index = nearestIndex(to: pt)
        if index != activeKeyIndex { setActiveKey(index) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pt = touches.first?.location(in: self),
              bounds.insetBy(dx: -12, dy: -18).contains(pt),
              let index = activeKeyIndex else {
            setActiveKey(nil)
            return
        }

        let action = keys[index].action
        setActiveKey(nil)
        action()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        setActiveKey(nil)
    }

    private func setActiveKey(_ index: Int?) {
        if let activeKeyIndex { keys[activeKeyIndex].label.alpha = 1 }
        activeKeyIndex = index

        guard let index else {
            keyPreview?.hide()
            return
        }

        let key = keys[index]
        key.label.alpha = 0.72
        if let preview = keyPreview, let container = previewContainer {
            preview.show(
                character: key.label.text ?? "",
                above: convert(key.frame, to: container),
                in: container
            )
        }
    }

    private func nearestIndex(to pt: CGPoint) -> Int {
        keys.indices.min {
            abs(keys[$0].frame.midX - pt.x) < abs(keys[$1].frame.midX - pt.x)
        } ?? 0
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

private final class EmojiCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "EmojiCollectionCell"
    private let emojiLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        emojiLabel.font = .systemFont(ofSize: 28)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(emojiLabel)
        NSLayoutConstraint.activate([
            emojiLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            emojiLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            emojiLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            emojiLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.45 : 1 }
    }

    func configure(emoji: String) {
        emojiLabel.text = emoji
    }
}

private final class EmojiSectionHeader: UICollectionReusableView {
    static let reuseIdentifier = "EmojiSectionHeader"
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) {
        titleLabel.text = title
    }
}

extension KeyboardViewController: AVAudioPlayerDelegate, UICollectionViewDataSource,
    UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        emojiCategories.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        emojiCategories[section].1.reduce(0) { $0 + $1.count }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: EmojiCollectionCell.reuseIdentifier,
            for: indexPath
        ) as! EmojiCollectionCell
        cell.configure(emoji: emoji(at: indexPath) ?? "")
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: EmojiSectionHeader.reuseIdentifier,
            for: indexPath
        ) as! EmojiSectionHeader
        header.configure(title: emojiCategories[indexPath.section].0)
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let emoji = emoji(at: indexPath) else { return }
        recordRecentEmoji(emoji)
        insertCharacter(emoji)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: floor((collectionView.bounds.width - 8) / 8), height: 38)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let collectionView = emojiCollectionView,
              scrollView === collectionView,
              let selectedIndex = collectionView.indexPathsForVisibleItems
                .map(\.section).min() else { return }
        selectEmojiCategory(selectedIndex)
    }

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
        let row1Tones: [(RewriteMode, String, String)] = [
            (.grammar, "grammar", "Grammar"), (.polish, "refine", "Refine"),
            (.warm, "warm", "Warm"),           (.professional, "professional", "Pro")
        ]
        let row2Tones: [(RewriteMode, String, String)] = [
            (.shorter, "shorter", "Short"), (.flirty, "flirty", "Flirty"),
            (.street, "street", "Vibe"),    (.funny, "funny", "Funny")
        ]

        func makeToneRow(_ items: [(RewriteMode, String, String)]) -> UIStackView {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 5
            row.distribution = .fillEqually
            row.translatesAutoresizingMaskIntoConstraints = false
            for (mode, emojiAsset, label) in items {
                let btn = UIButton(type: .custom)
                btn.setImage(Self.toneEmojiImage(named: emojiAsset), for: .normal)
                btn.setTitle(" \(label)", for: .normal)
                btn.titleLabel?.font = .systemFont(
                    ofSize: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 11,
                    weight: .medium
                )
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
        // diffTextView grows to absorb any extra height; everything below it is fixed size
        // and chained top-to-bottom so layout is unambiguous at any view height.
        NSLayoutConstraint.activate([
            diffTextView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            diffTextView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            diffTextView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            diffTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),

            loadingLabel.centerXAnchor.constraint(equalTo: diffTextView.centerXAnchor),
            loadingLabel.centerYAnchor.constraint(equalTo: diffTextView.centerYAnchor),

            toneRow1.topAnchor.constraint(equalTo: diffTextView.bottomAnchor, constant: 6),
            toneRow1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            toneRow1.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            toneRow1.heightAnchor.constraint(equalToConstant: 30),

            toneRow2.topAnchor.constraint(equalTo: toneRow1.bottomAnchor, constant: 5),
            toneRow2.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            toneRow2.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            toneRow2.heightAnchor.constraint(equalToConstant: 30),

            savedToneRow.topAnchor.constraint(equalTo: toneRow2.bottomAnchor, constant: 5),
            savedToneRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            savedToneRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            sh,

            customBtn.topAnchor.constraint(equalTo: savedToneRow.bottomAnchor, constant: 5),
            customBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            customBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            customBtn.heightAnchor.constraint(equalToConstant: 30),

            // Chain customBtn to bottomBar so the full top-to-bottom layout is unambiguous.
            bottomBar.topAnchor.constraint(equalTo: customBtn.bottomAnchor, constant: 6),
            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            bottomBar.heightAnchor.constraint(equalToConstant: 36),
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

    private static func toneEmojiImage(named name: String) -> UIImage? {
        guard let url = Bundle(for: AIReviewView.self).url(
            forResource: name,
            withExtension: "png",
            subdirectory: "ToneEmojiAssets"
        ), let source = UIImage(contentsOfFile: url.path) else { return nil }

        let side: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 16 : 14
        let size = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: size).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
    }

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

// MARK: - Language Picker Overlay

private final class LanguagePickerOverlay: UIView,
                                            UITableViewDataSource,
                                            UITableViewDelegate {

    private let allLanguages: [String]
    private let flagEmoji: [String: String]
    private var flagImages: [String: UIImage] = [:]
    private let currentSelection: String
    private let onSelect: (String) -> Void
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let titleLabel = UILabel()

    // MARK: - Factory

    static func show(in parent: UIView, title: String,
                     languages: [String], flags: [String: String], current: String,
                     onSelect: @escaping (String) -> Void) {
        parent.subviews.compactMap { $0 as? LanguagePickerOverlay }.forEach { $0.close() }

        let picker = LanguagePickerOverlay(
            languages: languages, flags: flags, current: current, onSelect: onSelect
        )
        picker.titleLabel.text = title
        picker.frame = parent.bounds
        picker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addSubview(picker)

        if let idx = languages.firstIndex(of: current) {
            DispatchQueue.main.async {
                picker.tableView.scrollToRow(
                    at: IndexPath(row: idx, section: 0), at: .middle, animated: false
                )
            }
        }
    }

    // MARK: - Init

    private init(languages: [String], flags: [String: String], current: String,
                 onSelect: @escaping (String) -> Void) {
        self.allLanguages = languages
        self.flagEmoji    = flags
        self.currentSelection = current
        self.onSelect     = onSelect
        super.init(frame: .zero)
        prerenderFlags(flags)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Pre-render emoji → UIImage to avoid text-render issues in extensions

    private func prerenderFlags(_ flags: [String: String]) {
        let side: CGFloat = 26
        let rect  = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        // AppleColorEmoji renders regional-indicator pairs correctly as a bitmap
        let font  = UIFont(name: "AppleColorEmoji", size: 20) ?? UIFont.systemFont(ofSize: 20)
        for (_, emoji) in flags where !emoji.isEmpty {
            let renderer = UIGraphicsImageRenderer(size: rect.size)
            let img = renderer.image { _ in
                (emoji as NSString).draw(in: rect, withAttributes: [.font: font])
            }
            flagImages[emoji] = img
        }
    }

    // MARK: - Setup

    private func setup() {
        backgroundColor = UIColor.systemBackground

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        let sym = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: sym), for: .normal)
        closeBtn.tintColor = .tertiaryLabel
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(close), for: .touchUpInside)
        addSubview(closeBtn)

        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor   = .systemBackground
        tableView.rowHeight          = 42
        tableView.isScrollEnabled    = true
        tableView.bounces            = true
        tableView.alwaysBounceVertical = true
        tableView.delaysContentTouches = false
        tableView.showsVerticalScrollIndicator = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            closeBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Dismiss

    @objc func close() {
        removeFromSuperview()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        allLanguages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let lang = allLanguages[indexPath.row]
        let emoji = flagEmoji[lang] ?? ""
        // Use legacy textLabel / imageView — simplest path, no UIListContentConfiguration quirks
        cell.textLabel?.text = lang
        cell.textLabel?.font = .systemFont(ofSize: 15)
        cell.imageView?.image = emoji.isEmpty ? nil : flagImages[emoji]
        cell.backgroundColor = .systemBackground
        cell.accessoryType   = lang == currentSelection ? .checkmark : .none
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect(allLanguages[indexPath.row])
        close()
    }
}
