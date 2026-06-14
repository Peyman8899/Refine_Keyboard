import UIKit

final class KeyboardViewController: UIInputViewController {
    private let client = RewriteClient()
    private var outputLanguage = KeyboardSettings.rewriteLanguage
    private let statusLabel = UILabel()
    private var polishButton: UIButton?
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
        modeRow.spacing = 5
        modeRow.distribution = .fillEqually
        RewriteMode.allCases.forEach { mode in
            let button = makeActionButton(title: title(for: mode))
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            button.addAction(UIAction { [weak self] _ in
                self?.refineCurrentText(mode: mode)
            }, for: .touchUpInside)
            if mode == .polish {
                polishButton = button
                button.menu = makeLanguageMenu()
                button.showsMenuAsPrimaryAction = false
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
        nextKeyboard.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        commandRow.addArrangedSubview(nextKeyboard)

        let globe = makeSystemButton(title: nil, imageName: "globe")
        globe.widthAnchor.constraint(equalToConstant: 44).isActive = true
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        commandRow.addArrangedSubview(globe)

        let space = makeKeyButton(title: "space")
        space.addAction(UIAction { [weak self] _ in
            self?.textDocumentProxy.insertText(" ")
        }, for: .touchUpInside)
        commandRow.addArrangedSubview(space)

        let enter = makeSystemButton(title: "return")
        enter.widthAnchor.constraint(equalToConstant: 78).isActive = true
        enter.addAction(UIAction { [weak self] _ in
            self?.textDocumentProxy.insertText("\n")
        }, for: .touchUpInside)
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
        shift.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.isShifted.toggle()
            self.refreshLetterCasing()
        }, for: .touchUpInside)
        row.addArrangedSubview(shift)

        let lettersRow = makeRow()
        "ZXCVBNM".forEach { lettersRow.addArrangedSubview(makeLetterButton(character: $0)) }
        row.addArrangedSubview(lettersRow)

        let delete = makeSystemButton(title: nil, imageName: "delete.left")
        delete.widthAnchor.constraint(equalToConstant: 44).isActive = true
        delete.addAction(UIAction { [weak self] _ in
            self?.textDocumentProxy.deleteBackward()
        }, for: .touchUpInside)
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
        button.addAction(UIAction { [weak self, weak button] _ in
            guard let self, let title = button?.configuration?.title else { return }
            self.textDocumentProxy.insertText(self.isShifted ? title.uppercased() : title.lowercased())
            if self.isShifted {
                self.isShifted = false
                self.refreshLetterCasing()
            }
        }, for: .touchUpInside)
        return button
    }

    private func refreshLetterCasing() {
        refreshLetterCasing(in: view)
    }

    private func refreshLetterCasing(in parent: UIView) {
        parent.subviews.forEach { child in
            if let button = child as? UIButton,
               let title = button.configuration?.title,
               title.count == 1,
               title.rangeOfCharacter(from: .letters) != nil {
                button.configuration?.title = title.uppercased()
            }
            refreshLetterCasing(in: child)
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
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
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
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
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
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
        return button
    }

    private func title(for mode: RewriteMode) -> String {
        switch mode {
        case .polish:
            return outputLanguage == "Auto" ? "Polish" : "Polish \(languageCode(for: outputLanguage))"
        case .warm:
            return "Warm"
        case .professional:
            return "Professional"
        case .shorter:
            return "Short"
        }
    }

    private func updatePolishButtonTitle() {
        polishButton?.configuration?.title = title(for: .polish)
        polishButton?.menu = makeLanguageMenu()
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
                self.updatePolishButtonTitle()
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
        polishButton?.configuration?.title = message

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                self?.updatePolishButtonTitle()
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
