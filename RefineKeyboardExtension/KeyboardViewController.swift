import UIKit

final class KeyboardViewController: UIInputViewController {
    private let client = RewriteClient()
    private var outputLanguage = KeyboardSettings.rewriteLanguage
    private let statusLabel = UILabel()
    private var polishButton: UIButton?

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
        view.backgroundColor = UIColor.systemBackground

        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        statusLabel.text = "Ready"
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        root.addArrangedSubview(statusLabel)

        let modeRow = UIStackView()
        modeRow.axis = .horizontal
        modeRow.spacing = 6
        modeRow.distribution = .fillEqually
        RewriteMode.allCases.forEach { mode in
            let button = makeButton(title: title(for: mode))
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

        ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"].forEach { rowText in
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 5
            row.distribution = .fillEqually
            rowText.forEach { character in
                let button = makeButton(title: String(character))
                button.addAction(UIAction { [weak self] _ in
                    self?.textDocumentProxy.insertText(String(character).lowercased())
                }, for: .touchUpInside)
                row.addArrangedSubview(button)
            }
            root.addArrangedSubview(row)
        }

        let commandRow = UIStackView()
        commandRow.axis = .horizontal
        commandRow.spacing = 6
        commandRow.distribution = .fill

        let nextKeyboard = makeButton(title: "Next")
        nextKeyboard.widthAnchor.constraint(equalToConstant: 48).isActive = true
        nextKeyboard.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        commandRow.addArrangedSubview(nextKeyboard)

        let space = makeButton(title: "space")
        space.addAction(UIAction { [weak self] _ in
            self?.textDocumentProxy.insertText(" ")
        }, for: .touchUpInside)
        commandRow.addArrangedSubview(space)

        let delete = makeButton(title: "Del")
        delete.widthAnchor.constraint(equalToConstant: 56).isActive = true
        delete.addAction(UIAction { [weak self] _ in
            self?.textDocumentProxy.deleteBackward()
        }, for: .touchUpInside)
        commandRow.addArrangedSubview(delete)

        let enter = makeButton(title: "return")
        enter.widthAnchor.constraint(equalToConstant: 74).isActive = true
        enter.addAction(UIAction { [weak self] _ in
            self?.textDocumentProxy.insertText("\n")
        }, for: .touchUpInside)
        commandRow.addArrangedSubview(enter)

        root.addArrangedSubview(commandRow)
    }

    private func makeButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = .secondarySystemBackground
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .medium
        configuration.titleLineBreakMode = .byTruncatingTail

        let button = UIButton(configuration: configuration)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.55
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
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
                self.statusLabel.text = "Language: \(language)"
            }
        }
        return UIMenu(title: "Output Language", children: actions)
    }

    private func refineCurrentText(mode: RewriteMode) {
        let text = (textDocumentProxy.documentContextBeforeInput ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            statusLabel.text = "Type a message first"
            return
        }

        statusLabel.text = "Refining..."

        Task { [weak self] in
            guard let self else { return }
            do {
                let refined = try await client.rewrite(text: text, mode: mode, language: outputLanguage)
                await MainActor.run {
                    if refined == text {
                        self.statusLabel.text = "No changes suggested"
                    } else {
                        self.replaceCurrentDraft(original: text, refined: refined)
                        self.statusLabel.text = "Inserted"
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.text = (error as? LocalizedError)?.errorDescription ?? "Could not refine"
                }
            }
        }
    }

    private func replaceCurrentDraft(original: String, refined: String) {
        guard !refined.isEmpty else { return }
        original.forEach { _ in
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(refined)
    }
}
