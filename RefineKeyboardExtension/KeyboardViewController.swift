import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum KeyboardMode {
        case letters
        case numbers
        case symbols
        case emoji
    }

    private let client = RewriteClient()
    private var outputLanguage = KeyboardSettings.rewriteLanguage
    private var languageButton: UIButton?
    private var statusTask: Task<Void, Never>?
    private var deleteTimer: Timer?
    private let keyboardStack = UIStackView()
    private var keyboardHeightConstraint: NSLayoutConstraint?
    private var letterButtons: [UIButton] = []
    private var shiftButton: UIButton?
    private var emojiScrollView: UIScrollView?
    private var emojiCategoryAnchors: [UIView] = []
    private var isShifted = true
    private var capsLocked = false
    private var lastShiftTapTime: Date?
    private var keyboardMode: KeyboardMode = .letters
    private var lastRewriteCharacterCount: Int?
    private let keyPreview = KeyPreviewView()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let translationBanner = TranslationBannerView()
    private var bannerDismissTask: Task<Void, Never>?
    private var lastTranslation: String?

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
        keyboardHeightConstraint = view.heightAnchor.constraint(equalToConstant: 258)
        keyboardHeightConstraint?.priority = .defaultHigh
        keyboardHeightConstraint?.isActive = true
        impactGenerator.prepare()
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

        let modeScroll = UIScrollView()
        modeScroll.showsHorizontalScrollIndicator = false
        modeScroll.alwaysBounceHorizontal = false
        modeScroll.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let modeRow = UIStackView()
        modeRow.axis = .horizontal
        modeRow.spacing = 4
        modeRow.distribution = .fill
        modeRow.translatesAutoresizingMaskIntoConstraints = false
        modeScroll.addSubview(modeRow)

        NSLayoutConstraint.activate([
            modeRow.leadingAnchor.constraint(equalTo: modeScroll.contentLayoutGuide.leadingAnchor),
            modeRow.trailingAnchor.constraint(equalTo: modeScroll.contentLayoutGuide.trailingAnchor),
            modeRow.topAnchor.constraint(equalTo: modeScroll.contentLayoutGuide.topAnchor),
            modeRow.bottomAnchor.constraint(equalTo: modeScroll.contentLayoutGuide.bottomAnchor),
            modeRow.heightAnchor.constraint(equalTo: modeScroll.frameLayoutGuide.heightAnchor),
        ])

        let language = makeActionButton(title: languageTitle())
        languageButton = language
        language.menu = makeLanguageMenu()
        language.showsMenuAsPrimaryAction = true
        modeRow.addArrangedSubview(language)

        let actions: [(String, RewriteMode)] = [
            ("Refine", .polish),
            ("Warm", .warm),
            ("Professional", .professional),
            ("Short", .shorter),
            ("Translate", .translate),
        ]
        actions.forEach { title, mode in
            let button = makeActionButton(title: title)
            addTapAction(to: button) { [weak self] in
                if mode == .translate {
                    self?.translateSelectedText()
                } else {
                    self?.refineCurrentText(mode: mode)
                }
            }
            modeRow.addArrangedSubview(button)
        }
        root.addArrangedSubview(modeScroll)

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
            self.bannerDismissTask?.cancel()
            self.translationBanner.hide()
        }

        renderKeyboard()
    }

    private func renderKeyboard() {
        keyboardStack.arrangedSubviews.forEach { view in
            keyboardStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        letterButtons.removeAll()
        shiftButton = nil
        emojiScrollView = nil
        emojiCategoryAnchors.removeAll()

        switch keyboardMode {
        case .letters:
            renderLetterKeyboard()
        case .numbers:
            renderNumberKeyboard()
        case .symbols:
            renderSymbolsKeyboard()
        case .emoji:
            renderEmojiKeyboard()
        }
    }

    private func renderLetterKeyboard() {
        keyboardStack.addArrangedSubview(makeLetterRow("qwertyuiop"))
        keyboardStack.addArrangedSubview(makeIndentedLetterRow("asdfghjkl", sideInset: 20))
        keyboardStack.addArrangedSubview(makeThirdLetterRow())
        keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "123"))
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

    private func makeLetterRow(_ letters: String) -> UIStackView {
        let row = makeRow()
        letters.forEach { row.addArrangedSubview(makeLetterButton(character: $0)) }
        return row
    }

    private func makeTextRow(_ keys: [String]) -> UIStackView {
        let row = makeRow()
        keys.forEach { key in
            let button = makeKeyButton(title: key)
            button.titleLabel?.font = .systemFont(ofSize: 24, weight: .regular)
            addCharacterAction(to: button) { [weak self] in
                self?.insertCharacter(key)
            }
            row.addArrangedSubview(button)
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

        let keysRow = makeRow()
        [".", ",", "?", "!", "'"].forEach { key in
            let button = makeKeyButton(title: key)
            button.titleLabel?.font = .systemFont(ofSize: 24, weight: .regular)
            addCharacterAction(to: button) { [weak self] in
                self?.insertCharacter(key)
            }
            keysRow.addArrangedSubview(button)
        }
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

    private func makeIndentedLetterRow(_ letters: String, sideInset: CGFloat) -> UIStackView {
        let container = makeRow()
        container.distribution = .fill
        container.addArrangedSubview(makeSpacer(width: sideInset))
        let lettersRow = makeLetterRow(letters)
        container.addArrangedSubview(lettersRow)
        container.addArrangedSubview(makeSpacer(width: sideInset))
        return container
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

        let lettersRow = makeRow()
        "zxcvbnm".forEach { lettersRow.addArrangedSubview(makeLetterButton(character: $0)) }
        row.addArrangedSubview(lettersRow)

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
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 5
        row.distribution = .fillEqually
        return row
    }

    private func makeSpacer(width: CGFloat) -> UIView {
        let view = UIView()
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        return view
    }

    private func makeLetterButton(character: Character) -> UIButton {
        let title = isShifted ? String(character).uppercased() : String(character).lowercased()
        let button = makeKeyButton(title: title)
        button.titleLabel?.font = .systemFont(ofSize: 24, weight: .regular)
        letterButtons.append(button)
        addCharacterAction(to: button) { [weak self] in
            guard let self else { return }
            let char = (self.isShifted || self.capsLocked)
                ? String(character).uppercased()
                : String(character).lowercased()
            self.insertCharacter(char)
            if self.isShifted && !self.capsLocked {
                self.isShifted = false
                // Defer casing refresh so text insertion renders first
                DispatchQueue.main.async { [weak self] in
                    self?.refreshLetterCasing()
                    self?.updateShiftAppearance()
                }
            }
        }
        return button
    }

    private func refreshLetterCasing() {
        letterButtons.forEach { button in
            let current = button.title(for: .normal) ?? ""
            button.setTitle(isShifted ? current.uppercased() : current.lowercased(), for: .normal)
        }
    }

    private func updateShiftAppearance() {
        guard let shiftButton else { return }
        let imageName = capsLocked ? "capslock.fill" : (isShifted ? "shift.fill" : "shift")
        let symCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        shiftButton.setImage(UIImage(systemName: imageName, withConfiguration: symCfg), for: .normal)
        shiftButton.layer.backgroundColor = ((isShifted || capsLocked) ? letterKeyBackground : specialKeyBackground).cgColor
    }

    private func makeActionButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = actionPillBackground
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .capsule
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            return out
        }

        let button = UIButton(configuration: configuration)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        addPressFeedback(to: button)
        return button
    }

    private func makeKeyButton(title: String, showsPreview: Bool = true) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.55
        button.titleLabel?.lineBreakMode = .byTruncatingTail
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
        UIDevice.current.playInputClick()
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
        insertUserText(text)
    }

    private func deleteCharacter() {
        UIDevice.current.playInputClick()
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
        deleteUserText()
    }

    private func insertUserText(_ text: String) {
        lastRewriteCharacterCount = nil
        textDocumentProxy.insertText(text)
    }

    private func deleteUserText() {
        lastRewriteCharacterCount = nil
        textDocumentProxy.deleteBackward()
    }

    private func addPressFeedback(to button: UIButton) {
        button.addAction(UIAction { [weak button] _ in
            button?.alpha = 0.72
        }, for: .touchDown)
        button.addAction(UIAction { [weak button] _ in
            button?.alpha = 1
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func languageTitle() -> String {
        outputLanguage == "Auto" ? "Auto" : outputLanguage
    }

    private func updateLanguageButtonTitle() {
        languageButton?.configuration?.title = languageTitle()
        languageButton?.menu = makeLanguageMenu()
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

    private func makeLanguageMenu() -> UIMenu {
        let rewriteActions = languages.map { language in
            UIAction(title: language, state: language == outputLanguage ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.outputLanguage = language
                KeyboardSettings.sharedDefaults.set(language, forKey: KeyboardSettings.languageKey)
                self.updateLanguageButtonTitle()
                self.showStatus(language == "Auto" ? "Rewrite: Auto" : "Rewrite → \(self.languageCode(for: language))")
            }
        }

        let translateLang = KeyboardSettings.translateLanguage
        let translateActions = languages.filter { $0 != "Auto" }.map { language in
            UIAction(title: language, state: language == translateLang ? .on : .off) { [weak self] _ in
                guard let self else { return }
                KeyboardSettings.sharedDefaults.set(language, forKey: KeyboardSettings.translateLanguageKey)
                self.showStatus("Translate → \(self.languageCode(for: language))")
            }
        }

        let rewriteMenu = UIMenu(
            title: "Rewrite Language",
            image: UIImage(systemName: "pencil"),
            children: rewriteActions
        )
        let translateMenu = UIMenu(
            title: "Translate To",
            image: UIImage(systemName: "character.bubble"),
            children: translateActions
        )
        return UIMenu(title: "", options: .displayInline, children: [rewriteMenu, translateMenu])
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

        let contextBeforeInput = textDocumentProxy.documentContextBeforeInput ?? ""
        let contextAfterInput = textDocumentProxy.documentContextAfterInput ?? ""
        let fullDraft = contextBeforeInput + contextAfterInput
        let text = fullDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            showStatus("Type first")
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
            showStatus("Enable Full Access")
            return
        }
        guard KeyboardSettings.isSubscriptionActive else {
            showStatus("Open RefineKeyboard app to subscribe")
            return
        }

        // Selected text in input field takes priority; clipboard is the fallback
        // (keyboard extensions cannot read selections from message bubbles)
        let text = [
            textDocumentProxy.selectedText,
            UIPasteboard.general.string
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }

        guard let source = text else {
            showStatus("Copy a message first")
            return
        }

        let targetLanguage = KeyboardSettings.translateLanguage
        showStatus("Translating...")
        bannerDismissTask?.cancel()
        translationBanner.hide(animated: false)

        Task { [weak self] in
            guard let self else { return }
            do {
                let translated = try await client.rewrite(text: source, mode: .translate, language: targetLanguage)
                await MainActor.run {
                    self.lastTranslation = translated
                    self.updateLanguageButtonTitle()
                    self.showTranslation(translated, language: targetLanguage)
                }
            } catch {
                await MainActor.run {
                    self.showStatus(self.message(for: error))
                }
            }
        }
    }

    private func showTranslation(_ text: String, language: String) {
        bannerDismissTask?.cancel()
        translationBanner.show(translation: text, language: language)
        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.translationBanner.hide() }
        }
    }

    private func showStatus(_ message: String) {
        statusTask?.cancel()
        languageButton?.configuration?.title = message
        statusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.updateLanguageButtonTitle() }
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

extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

final class TranslationBannerView: UIView {
    var onTap: (() -> Void)?

    private let headerLabel = UILabel()
    private let bodyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
        alpha = 0

        backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 0.95)
        layer.cornerRadius = 12
        layer.masksToBounds = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4

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

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
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

    @objc private func tapped() { onTap?() }
}
