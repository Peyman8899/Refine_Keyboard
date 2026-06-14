import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum KeyboardMode {
        case letters
        case numbers
        case emoji
    }

    private let client = RewriteClient()
    private var outputLanguage = KeyboardSettings.rewriteLanguage
    private let statusLabel = UILabel()
    private var languageButton: UIButton?
    private let keyboardStack = UIStackView()
    private var keyboardHeightConstraint: NSLayoutConstraint?
    private var letterButtons: [UIButton] = []
    private var isShifted = false
    private var keyboardMode: KeyboardMode = .letters
    private var lastRewriteCharacterCount: Int?

    private let keyboardBackground = UIColor(red: 0.84, green: 0.86, blue: 0.89, alpha: 1)
    private let systemKeyBackground = UIColor(red: 0.69, green: 0.72, blue: 0.77, alpha: 1)
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
        setupKeyboard()
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

        statusLabel.text = "Ready"
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center

        let modeRow = UIStackView()
        modeRow.axis = .horizontal
        modeRow.spacing = 4
        modeRow.distribution = .fillEqually

        let language = makeActionButton(title: languageTitle())
        languageButton = language
        language.menu = makeLanguageMenu()
        language.showsMenuAsPrimaryAction = true
        modeRow.addArrangedSubview(language)

        let actions: [(String, RewriteMode)] = [
            ("Refine", .polish),
            ("Warm", .warm),
            ("Professional", .professional),
            ("Short", .shorter)
        ]
        actions.forEach { title, mode in
            let button = makeActionButton(title: title)
            addTapAction(to: button) { [weak self] in
                self?.refineCurrentText(mode: mode)
            }
            modeRow.addArrangedSubview(button)
        }
        root.addArrangedSubview(modeRow)

        keyboardStack.axis = .vertical
        keyboardStack.spacing = 6
        keyboardStack.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(keyboardStack)
        renderKeyboard()
    }

    private func renderKeyboard() {
        keyboardStack.arrangedSubviews.forEach { view in
            keyboardStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        letterButtons.removeAll()

        switch keyboardMode {
        case .letters:
            renderLetterKeyboard()
        case .numbers:
            renderNumberKeyboard()
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
        keyboardStack.addArrangedSubview(makeSymbolRow())
        keyboardStack.addArrangedSubview(makeCommandRow(modeTitle: "ABC"))
    }

    private func renderEmojiKeyboard() {
        keyboardStack.addArrangedSubview(makeEmojiPager())
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

        let space = makeKeyButton(title: "space")
        addTapAction(to: space) { [weak self] in
            self?.insertUserText(" ")
        }
        commandRow.addArrangedSubview(space)

        let enter = makeSystemButton(title: "return")
        enter.widthAnchor.constraint(equalToConstant: 82).isActive = true
        addTapAction(to: enter) { [weak self] in
            self?.insertUserText("\n")
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
            addTapAction(to: button) { [weak self] in
                self?.insertUserText(key)
            }
            row.addArrangedSubview(button)
        }
        return row
    }

    private func makeSymbolRow() -> UIStackView {
        let row = makeRow()
        row.distribution = .fill

        let symbols = makeSystemButton(title: "#+=")
        symbols.widthAnchor.constraint(equalToConstant: 58).isActive = true
        addTapAction(to: symbols) { [weak self] in
            self?.showStatus("More symbols")
        }
        row.addArrangedSubview(symbols)

        let keysRow = makeRow()
        [".", ",", "?", "!", "'"].forEach { key in
            let button = makeKeyButton(title: key)
            button.titleLabel?.font = .systemFont(ofSize: 24, weight: .regular)
            addTapAction(to: button) { [weak self] in
                self?.insertUserText(key)
            }
            keysRow.addArrangedSubview(button)
        }
        row.addArrangedSubview(keysRow)

        let delete = makeSystemButton(title: nil, imageName: "delete.left")
        delete.widthAnchor.constraint(equalToConstant: 58).isActive = true
        addTapAction(to: delete) { [weak self] in
            self?.deleteUserText()
        }
        row.addArrangedSubview(delete)

        return row
    }

    private func makeEmojiRow(_ emojis: [String]) -> UIStackView {
        let row = makeRow()
        emojis.forEach { emoji in
            let button = makeFlatEmojiButton(title: emoji)
            addTapAction(to: button) { [weak self] in
                self?.insertUserText(emoji)
            }
            row.addArrangedSubview(button)
        }
        return row
    }

    private func makeEmojiPager() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.isPagingEnabled = true
        scrollView.heightAnchor.constraint(equalToConstant: 154).isActive = true

        let pages = UIStackView()
        pages.axis = .horizontal
        pages.spacing = 16
        pages.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(pages)

        emojiCategories.forEach { title, rows in
            let page = makeEmojiCategoryPage(title: title, rows: rows)
            page.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -8).isActive = true
            pages.addArrangedSubview(page)
        }

        NSLayoutConstraint.activate([
            pages.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            pages.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            pages.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            pages.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            pages.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

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
        addTapAction(to: shift) { [weak self] in
            guard let self else { return }
            self.isShifted.toggle()
            self.refreshLetterCasing()
        }
        row.addArrangedSubview(shift)

        let lettersRow = makeRow()
        "zxcvbnm".forEach { lettersRow.addArrangedSubview(makeLetterButton(character: $0)) }
        row.addArrangedSubview(lettersRow)

        let delete = makeSystemButton(title: nil, imageName: "delete.left")
        delete.widthAnchor.constraint(equalToConstant: 58).isActive = true
        addTapAction(to: delete) { [weak self] in
            self?.deleteUserText()
        }
        row.addArrangedSubview(delete)

        return row
    }

    private func makeEmojiTabsRow() -> UIStackView {
        let row = makeRow()
        row.distribution = .fill

        let abc = UIButton(type: .system)
        abc.setTitle("ABC", for: .normal)
        abc.setTitleColor(.label, for: .normal)
        abc.titleLabel?.font = .systemFont(ofSize: 18, weight: .regular)
        abc.widthAnchor.constraint(equalToConstant: 44).isActive = true
        addTapAction(to: abc) { [weak self] in
            self?.keyboardMode = .letters
            self?.renderKeyboard()
        }
        row.addArrangedSubview(abc)

        ["😎", "◒", "◷", "☺", "🐶", "🍎", "⚽", "🚗", "♡", "⚑"].forEach { title in
            let label = UILabel()
            label.text = title
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 20, weight: .regular)
            label.textColor = .secondaryLabel
            row.addArrangedSubview(label)
        }

        let delete = UIButton(type: .system)
        delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
        delete.tintColor = .label
        delete.widthAnchor.constraint(equalToConstant: 44).isActive = true
        addTapAction(to: delete) { [weak self] in
            self?.deleteUserText()
        }
        row.addArrangedSubview(delete)

        return row
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
        let button = makeKeyButton(title: String(character).lowercased())
        button.titleLabel?.font = .systemFont(ofSize: 24, weight: .regular)
        letterButtons.append(button)
        addTapAction(to: button) { [weak self, weak button] in
            guard let self, let title = button?.configuration?.title else { return }
            self.insertUserText(self.isShifted ? title.uppercased() : title.lowercased())
            if self.isShifted {
                self.isShifted = false
                self.refreshLetterCasing()
            }
        }
        return button
    }

    private func refreshLetterCasing() {
        letterButtons.forEach { button in
            let title = button.configuration?.title ?? ""
            button.configuration?.title = isShifted ? title.uppercased() : title.lowercased()
        }
    }

    private func makeActionButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = UIColor(red: 0.92, green: 0.93, blue: 0.96, alpha: 1)
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .medium
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)

        let button = UIButton(configuration: configuration)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.5
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        addPressFeedback(to: button)
        return button
    }

    private func makeKeyButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .medium
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2)

        let button = UIButton(configuration: configuration)
        button.layer.borderColor = UIColor.black.withAlphaComponent(0.04).cgColor
        button.layer.borderWidth = 0.5
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.55
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        addPressFeedback(to: button)
        return button
    }

    private func makeSystemButton(title: String?, imageName: String? = nil) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = systemKeyBackground
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .medium
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        if let imageName {
            configuration.image = UIImage(systemName: imageName)
        }

        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .regular)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
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
        let handler = UIAction { _ in action() }
        button.addAction(handler, for: .touchUpInside)
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
        let actions = languages.map { language in
            UIAction(title: language, state: language == outputLanguage ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.outputLanguage = language
                KeyboardSettings.sharedDefaults.set(language, forKey: KeyboardSettings.languageKey)
                self.updateLanguageButtonTitle()
                self.showStatus(language == "Auto" ? "Language: Auto" : "Language: \(languageCode(for: language))")
            }
        }
        return UIMenu(title: "Output Language", children: actions)
    }

    private func refineCurrentText(mode: RewriteMode) {
        guard hasFullAccess else {
            showStatus("Enable Full Access")
            return
        }

        let contextBeforeInput = textDocumentProxy.documentContextBeforeInput ?? ""
        let text = contextBeforeInput.trimmingCharacters(in: .whitespacesAndNewlines)

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
                        self.replaceCurrentDraft(contextBeforeInput: contextBeforeInput, refined: refined)
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

    private func showStatus(_ message: String) {
        statusLabel.text = message

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                self?.updateLanguageButtonTitle()
            }
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

    private func replaceCurrentDraft(contextBeforeInput: String, refined: String) {
        guard !refined.isEmpty else { return }
        let deletionCount = max(contextBeforeInput.count, lastRewriteCharacterCount ?? 0)
        (0..<deletionCount).forEach { _ in
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(refined)
        lastRewriteCharacterCount = refined.count
    }
}
