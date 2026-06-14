import UIKit

final class KeyboardViewController: UIInputViewController {
    private let client = RewriteClient()
    private var outputLanguage = KeyboardSettings.rewriteLanguage
    private let statusLabel = UILabel()
    private var languageButton: UIButton?
    private var letterButtons: [UIButton] = []
    private var isShifted = false

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
        setupKeyboard()
    }

    private func setupKeyboard() {
        view.backgroundColor = UIColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1)

        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 7
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4)
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

        root.addArrangedSubview(makeLetterRow("QWERTYUIOP"))
        root.addArrangedSubview(makeIndentedLetterRow("ASDFGHJKL", sideInset: 18))
        root.addArrangedSubview(makeThirdLetterRow())

        let commandRow = UIStackView()
        commandRow.axis = .horizontal
        commandRow.spacing = 6
        commandRow.distribution = .fill

        let nextKeyboard = makeSystemButton(title: "123")
        nextKeyboard.widthAnchor.constraint(equalToConstant: 54).isActive = true
        commandRow.addArrangedSubview(nextKeyboard)

        let stickers = makeStickerButton()
        stickers.widthAnchor.constraint(equalToConstant: 44).isActive = true
        commandRow.addArrangedSubview(stickers)

        let space = makeKeyButton(title: "space")
        addTapAction(to: space) { [weak self] in
            self?.textDocumentProxy.insertText(" ")
        }
        commandRow.addArrangedSubview(space)

        let enter = makeSystemButton(title: "return")
        enter.widthAnchor.constraint(equalToConstant: 78).isActive = true
        addTapAction(to: enter) { [weak self] in
            self?.textDocumentProxy.insertText("\n")
        }
        commandRow.addArrangedSubview(enter)

        root.addArrangedSubview(commandRow)
    }

    private func makeLetterRow(_ letters: String) -> UIStackView {
        let row = makeRow()
        letters.forEach { row.addArrangedSubview(makeLetterButton(character: $0)) }
        return row
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
        shift.widthAnchor.constraint(equalToConstant: 44).isActive = true
        addTapAction(to: shift) { [weak self] in
            guard let self else { return }
            self.isShifted.toggle()
            self.refreshLetterCasing()
        }
        row.addArrangedSubview(shift)

        let lettersRow = makeRow()
        "ZXCVBNM".forEach { lettersRow.addArrangedSubview(makeLetterButton(character: $0)) }
        row.addArrangedSubview(lettersRow)

        let delete = makeSystemButton(title: nil, imageName: "delete.left")
        delete.widthAnchor.constraint(equalToConstant: 44).isActive = true
        addTapAction(to: delete) { [weak self] in
            self?.textDocumentProxy.deleteBackward()
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
        let button = makeKeyButton(title: String(character).uppercased())
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
        letterButtons.append(button)
        addTapAction(to: button) { [weak self, weak button] in
            guard let self, let title = button?.configuration?.title else { return }
            self.textDocumentProxy.insertText(self.isShifted ? title.uppercased() : title.lowercased())
            if self.isShifted {
                self.isShifted = false
                self.refreshLetterCasing()
            }
        }
        return button
    }

    private func refreshLetterCasing() {
        letterButtons.forEach { button in
            button.configuration?.title = button.configuration?.title?.uppercased()
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
        button.titleLabel?.minimumScaleFactor = 0.55
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return button
    }

    private func makeKeyButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .small
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2)

        let button = UIButton(configuration: configuration)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.22
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.55
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return button
    }

    private func makeSystemButton(title: String?, imageName: String? = nil) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = UIColor(red: 0.68, green: 0.71, blue: 0.76, alpha: 1)
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .small
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        if let imageName {
            configuration.image = UIImage(systemName: imageName)
        }

        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return button
    }

    private func makeStickerButton() -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "face.smiling")
        configuration.baseBackgroundColor = UIColor(red: 0.68, green: 0.71, blue: 0.76, alpha: 1)
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .small
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)

        let button = UIButton(configuration: configuration)
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return button
    }

    private func addTapAction(to button: UIButton, action: @escaping () -> Void) {
        let handler = UIAction { _ in action() }
        button.addAction(handler, for: .touchUpInside)
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

        let text = (textDocumentProxy.documentContextBeforeInput ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

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
                        self.replaceCurrentDraft(original: text, refined: refined)
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
        languageButton?.configuration?.title = message

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

    private func replaceCurrentDraft(original: String, refined: String) {
        guard !refined.isEmpty else { return }
        original.forEach { _ in
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(refined)
    }
}
